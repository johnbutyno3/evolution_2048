const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const crypto = require('crypto');
const { enforceSensitiveOperation } = require('./security_enforcement');
const { replayGame, allowedToolsForChapter } = require('./replay_validator');
const { recordSecurityEvent: recordAuditEvent } = require('./security_audit');
const {
  NORMAL_CAP,
  resolveMembership,
  intervalMs,
  normalizeLives,
  normalizeRegenStart,
  regenerate,
  lifeResponse,
} = require('./game_session_helpers');

const db = getFirestore();
const MAX_CHAPTER_INDEX = 5;
const GAME_SESSION_TTL_MS = 2 * 60 * 60 * 1000;
const STAGE_COUNTS = [12, 13, 14, 15, 16, 17];
const TARGETS = STAGE_COUNTS.map((stageCount) => 2 ** stageCount);
const CHAPTER_NAMES = ['ocean', 'land', 'sky', 'history', 'tech', 'universe'];

function recordSecurityEvent({ uid, action, severity = 'warning', reason, details = {} }) {
  return recordAuditEvent(db, { uid, action, severity, reason, details });
}

function lifeRef(uid) {
  return db.collection('users').doc(uid).collection('life').doc('current');
}

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
}

function progressRef(uid) {
  return db.collection('users').doc(uid).collection('progress').doc('game');
}

function gameSessionRef(uid, sessionId) {
  return db.collection('users').doc(uid).collection('game_sessions').doc(sessionId);
}

function toolInventoryRef(uid) {
  return db.collection('users').doc(uid).collection('wallet').doc('tools');
}

exports.restartGameSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'restart_game_session');

  const chapterIndex = request.data?.chapterIndex;
  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 ||
      chapterIndex > MAX_CHAPTER_INDEX) {
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }

  const uid = request.auth.uid;
  const newSessionId = crypto.randomUUID();
  const startedAt = new Date();
  const expiresAt = new Date(startedAt.getTime() + GAME_SESSION_TTL_MS);
  const newSessionRef = gameSessionRef(uid, newSessionId);
  const progress = progressRef(uid);
  const life = lifeRef(uid);
  const membership = membershipRef(uid);

  const replayLog = request.data?.replayLog ?? null;
  let replayResult = null;
  if (replayLog != null) {
    const requestedSessionId = request.data?.sessionId;
    let oldSessionId = typeof requestedSessionId === 'string' &&
        requestedSessionId.length > 0
      ? requestedSessionId
      : null;
    if (oldSessionId == null) {
      const oldSessionIdSnapshot = await progress.get();
      oldSessionId = oldSessionIdSnapshot.data()?.activeGameSessionId;
    }
    if (typeof oldSessionId === 'string' && oldSessionId.length > 0) {
      const oldSessionSnapshot = await gameSessionRef(uid, oldSessionId).get();
      if (oldSessionSnapshot.exists && oldSessionSnapshot.data()?.status === 'active') {
        const oldSession = oldSessionSnapshot.data() || {};
        const userSnapshot = await db.collection('users').doc(uid).get();
        const allToolsEnabledForTest = userSnapshot.data()?.allToolsEnabledForTest === true;
        try {
          replayResult = replayGame({
            replayLog,
            chapterIndex: oldSession.chapterIndex,
            targetValue: oldSession.targetValue,
            allowedTools: allowedToolsForChapter(
              oldSession.chapterIndex,
              allToolsEnabledForTest,
            ),
            requireCompletion: false,
          });
        } catch (error) {
          await recordSecurityEvent({
            uid,
            action: 'restart_game_session',
            severity: 'CRITICAL',
            reason: 'forged_replay_detected',
            details: {
              sessionId: oldSessionId,
              error: error?.message || 'Replay validation failed.',
            },
          });
          throw new HttpsError('permission-denied', 'Account security validation failed.');
        }
      }
    }
  }

  return db.runTransaction(async (transaction) => {
    const progressSnapshot = await transaction.get(progress);
    const membershipSnapshot = await transaction.get(membership);
    const lifeSnapshot = await transaction.get(life);
    const toolsSnapshot = replayResult
      ? await transaction.get(toolInventoryRef(uid))
      : null;

    const currentProgress = progressSnapshot.data() || {};
    const currentUnlocked = Number.isInteger(currentProgress.unlockedChapterIndex)
      ? Math.min(Math.max(currentProgress.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;

    if (chapterIndex > currentUnlocked) {
      throw new HttpsError('permission-denied', 'Chapter is not unlocked.');
    }

    const oldSessionId = currentProgress.activeGameSessionId;
    const oldSessionChapter = currentProgress.activeGameChapterIndex;
    let oldSessionRef = null;
    let oldSessionSnapshot = null;

    if (typeof oldSessionId === 'string' && oldSessionId.length > 0) {
      oldSessionRef = gameSessionRef(uid, oldSessionId);
      oldSessionSnapshot = await transaction.get(oldSessionRef);
      if (oldSessionSnapshot.exists &&
          oldSessionSnapshot.data()?.status === 'active' &&
          oldSessionChapter !== chapterIndex) {
        throw new HttpsError(
          'failed-precondition',
          'An unfinished game session exists in another chapter.',
        );
      }
    }

    const membershipState = resolveMembership(membershipSnapshot.data() || {});
    let lives = normalizeLives(lifeSnapshot.data()?.lives);
    let regenStartMillis = normalizeRegenStart(lifeSnapshot.data()?.regenStartAt);
    const nowMillis = Date.now();

    if (membershipState.infiniteLives) {
      lives = NORMAL_CAP;
      regenStartMillis = null;
    } else {
      const regenerated = regenerate({
        lives,
        regenStartMillis,
        nowMillis,
        interval: intervalMs(membershipState),
      });
      lives = regenerated.lives;
      regenStartMillis = regenerated.regenStartMillis;
    }

    if (!membershipState.infiniteLives && lives <= 0) {
      throw new HttpsError('failed-precondition', 'No lives available.');
    }

    if (replayResult != null && oldSessionSnapshot?.exists &&
        oldSessionSnapshot.data()?.status === 'active') {
      const previousUsage = oldSessionSnapshot.data()?.toolUsage &&
          typeof oldSessionSnapshot.data()?.toolUsage === 'object'
        ? oldSessionSnapshot.data().toolUsage
        : {};
      const inventory = toolsSnapshot?.data() || {};
      const toolUpdates = {};

      for (const toolType of Object.keys(replayResult.toolUsage)) {
        const totalUses = replayResult.toolUsage[toolType] ?? 0;
        const settledUses = previousUsage[toolType] ?? 0;
        if (!Number.isSafeInteger(totalUses) || totalUses < 0 ||
            !Number.isSafeInteger(settledUses) || settledUses < 0 ||
            totalUses < settledUses) {
          await recordSecurityEvent({
            uid,
            action: 'restart_game_session',
            severity: 'CRITICAL',
            reason: 'tool_usage_tampering_detected',
            details: { sessionId: oldSessionId, toolType, totalUses, settledUses },
          });
          throw new HttpsError('permission-denied', 'Account security validation failed.');
        }
        const delta = totalUses - settledUses;
        const goldenUnlimitedUndo = membershipState.active &&
            membershipState.type === 'golden' && toolType === 'timeRewind';
        if (delta === 0 || goldenUnlimitedUndo) continue;
        const currentUses = inventory[toolType] ?? 0;
        if (!Number.isSafeInteger(currentUses) || currentUses < delta) {
          await recordSecurityEvent({
            uid,
            action: 'restart_game_session',
            severity: 'CRITICAL',
            reason: 'tool_inventory_overuse_detected',
            details: { sessionId: oldSessionId, toolType, delta, currentUses },
          });
          throw new HttpsError('permission-denied', 'Account security validation failed.');
        }
        toolUpdates[toolType] = currentUses - delta;
      }

      if (Object.keys(toolUpdates).length > 0) {
        transaction.set(toolInventoryRef(uid), toolUpdates, { merge: true });
      }
      transaction.update(oldSessionRef, {
        toolUsage: replayResult.toolUsage,
        finalScore: replayResult.score,
        finalHighestValue: replayResult.highestValue,
      });
    }

    const nextLives = membershipState.infiniteLives ? lives : lives - 1;
    const nextRegenStart = nextLives < NORMAL_CAP
      ? (regenStartMillis ?? nowMillis)
      : null;

    if (oldSessionSnapshot?.exists && oldSessionSnapshot.data()?.status === 'active') {
      transaction.update(oldSessionRef, {
        status: 'replaced',
        replacedAt: FieldValue.serverTimestamp(),
      });
    }

    transaction.set(life, {
      lives: nextLives,
      regenStartAt: nextRegenStart == null
        ? null
        : Timestamp.fromMillis(nextRegenStart),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(progress, {
      activeGameSessionId: newSessionId,
      activeGameChapterIndex: chapterIndex,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.create(newSessionRef, {
      chapterIndex,
      targetValue: TARGETS[chapterIndex],
      status: 'active',
      startedAt,
      expiresAt,
      toolUsage: {},
      createdAt: FieldValue.serverTimestamp(),
      replacedSessionId: typeof oldSessionId === 'string' ? oldSessionId : null,
      replacedSessionChapterIndex: Number.isInteger(oldSessionChapter)
        ? oldSessionChapter
        : null,
    });

    return {
      sessionId: newSessionId,
      chapterIndex,
      targetValue: TARGETS[chapterIndex],
      expiresAt: expiresAt.toISOString(),
      ...lifeResponse(nextLives, nextRegenStart, membershipState),
    };
  });
});

exports.abandonGameSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'abandon_game_session');

  const sessionId = request.data?.sessionId;
  if (typeof sessionId !== 'string' || sessionId.length < 16 || sessionId.length > 128) {
    throw new HttpsError('invalid-argument', 'Invalid game session.');
  }

  const unfinishedExit = request.data?.unfinishedExit === true;
  const replayLog = request.data?.replayLog ?? null;
  const uid = request.auth.uid;
  const sessionRef = gameSessionRef(uid, sessionId);
  const progress = progressRef(uid);
  const life = lifeRef(uid);
  let replayResult = null;
  if (replayLog != null) {
    const precheckSnapshot = await sessionRef.get();
    if (precheckSnapshot.exists && precheckSnapshot.data()?.status === 'active') {
      const precheckSession = precheckSnapshot.data() || {};
      const userSnapshot = await db.collection('users').doc(uid).get();
      const allToolsEnabledForTest =
        userSnapshot.data()?.allToolsEnabledForTest === true;
      try {
        replayResult = replayGame({
          replayLog,
          chapterIndex: precheckSession.chapterIndex,
          targetValue: precheckSession.targetValue,
          allowedTools: allowedToolsForChapter(
            precheckSession.chapterIndex,
            allToolsEnabledForTest,
          ),
          requireCompletion: false,
        });
      } catch (error) {
        await recordSecurityEvent({
          uid,
          action: 'abandon_game_session',
          severity: 'CRITICAL',
          reason: 'forged_replay_detected',
          details: {
            sessionId,
            error: error?.message || 'Replay validation failed.',
          },
        });
        throw new HttpsError(
          'permission-denied',
          'Account security validation failed.',
        );
      }
    }
  }

  const membership = membershipRef(uid);

  let finalStatus = 'ended';

  const transactionResult = await db.runTransaction(async (transaction) => {
    // All transaction reads must happen before any writes.
    const sessionSnapshot = await transaction.get(sessionRef);
    const progressSnapshot = await transaction.get(progress);
    const membershipSnapshot = unfinishedExit
      ? await transaction.get(membership)
      : null;
    const lifeSnapshot = unfinishedExit
      ? await transaction.get(life)
      : null;
    const toolsSnapshot = replayResult
      ? await transaction.get(toolInventoryRef(uid))
      : null;

    if (!sessionSnapshot.exists) {
      return { status: 'ended', life: null };
    }

    const session = sessionSnapshot.data() || {};
    const current = progressSnapshot.data() || {};

    if (session.status !== 'active') {
      finalStatus = session.status || 'ended';
      return { status: finalStatus, life: null };
    }

    if (replayResult != null) {
      const previousUsage = session.toolUsage &&
          typeof session.toolUsage === 'object'
        ? session.toolUsage
        : {};
      const inventory = toolsSnapshot?.data() || {};
      const membershipState = resolveMembership(
        membershipSnapshot?.data() || {},
      );
      const toolUpdates = {};

      for (const toolType of Object.keys(replayResult.toolUsage)) {
        const totalUses = replayResult.toolUsage[toolType] ?? 0;
        const settledUses = previousUsage[toolType] ?? 0;

        if (!Number.isSafeInteger(totalUses) ||
            totalUses < 0 ||
            !Number.isSafeInteger(settledUses) ||
            settledUses < 0 ||
            totalUses < settledUses) {
          await recordSecurityEvent({
            uid,
            action: 'abandon_game_session',
            severity: 'CRITICAL',
            reason: 'tool_usage_tampering_detected',
            details: { sessionId, toolType, totalUses, settledUses },
          });
          throw new HttpsError(
            'permission-denied',
            'Account security validation failed.',
          );
        }

        const delta = totalUses - settledUses;
        const goldenUnlimitedUndo =
          membershipState.active &&
          membershipState.type === 'golden' &&
          toolType === 'timeRewind';

        if (delta === 0 || goldenUnlimitedUndo) continue;

        const currentUses = inventory[toolType] ?? 0;
        if (!Number.isSafeInteger(currentUses) ||
            currentUses < delta) {
          await recordSecurityEvent({
            uid,
            action: 'abandon_game_session',
            severity: 'CRITICAL',
            reason: 'tool_inventory_overuse_detected',
            details: {
              sessionId,
              toolType,
              delta,
              currentUses,
            },
          });
          throw new HttpsError(
            'permission-denied',
            'Account security validation failed.',
          );
        }

        toolUpdates[toolType] = currentUses - delta;
      }

      if (Object.keys(toolUpdates).length > 0) {
        transaction.set(
          toolInventoryRef(uid),
          {
            ...toolUpdates,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      const chapterName = CHAPTER_NAMES[session.chapterIndex];
      const existingChapterProgress =
          current.chapterProgress &&
          typeof current.chapterProgress === 'object'
        ? current.chapterProgress
        : {};
      const existingChapter = existingChapterProgress[chapterName] || {};
      const existingHighest = Number.isInteger(existingChapter.highestValue)
        ? existingChapter.highestValue
        : 0;
      const existingScore = Number.isSafeInteger(existingChapter.score)
        ? existingChapter.score
        : 0;
      const settledHighest = Math.max(existingHighest, replayResult.highestValue);
      const settledScore = Math.max(existingScore, replayResult.score);
      settledChapterProgress = {
        [chapterName]: {
          highestValue: settledHighest,
          score: settledScore,
        },
      };
      transaction.set(progress, {
        chapterProgress: {
          [chapterName]: {
            highestValue: settledHighest,
            score: settledScore,
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(sessionRef, {
        toolUsage: replayResult.toolUsage,
        replayEventCount: replayResult.eventCount,
        toolPenaltyTotal: replayResult.toolPenaltyTotal,
        toolsLastSettledAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }



    if (unfinishedExit) {
      // Leaving an unfinished game is not Game Over. Refund exactly the Life
      // consumed for this entry and keep the same server-owned session active.
      // resumeGameSession clears this marker before each new billable entry,
      // so each unfinished entry can receive exactly one refund.
      if (current.activeGameSessionId !== sessionId) {
        throw new HttpsError(
          'failed-precondition',
          'Game session is not the current active game.',
        );
      }

      if (session.unfinishedExitRefundedAt == null) {
        const membershipState = resolveMembership(
          membershipSnapshot?.data() || {},
        );
        let lives = normalizeLives(lifeSnapshot?.data()?.lives);
        let regenStartMillis = normalizeRegenStart(
          lifeSnapshot?.data()?.regenStartAt,
        );
        const nowMillis = Date.now();

        if (membershipState.infiniteLives) {
          lives = NORMAL_CAP;
          regenStartMillis = null;
        } else {
          const regenerated = regenerate({
            lives,
            regenStartMillis,
            nowMillis,
            interval: intervalMs(membershipState),
          });
          lives = regenerated.lives;
          regenStartMillis = regenerated.regenStartMillis;

          lives = Math.min(NORMAL_CAP, lives + 1);
          if (lives >= NORMAL_CAP) {
            regenStartMillis = null;
          } else if (regenStartMillis == null) {
            regenStartMillis = nowMillis;
          }
        }

        transaction.set(life, {
          lives,
          regenStartAt: regenStartMillis == null
            ? null
            : Timestamp.fromMillis(regenStartMillis),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        transaction.set(sessionRef, {
          unfinishedExitRefundedAt: FieldValue.serverTimestamp(),
          lastUnfinishedExitAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        finalStatus = 'active';
        return {
          status: 'active',
          life: lifeResponse(lives, regenStartMillis, membershipState),
        };
      }

      finalStatus = 'active';
      return { status: 'active', life: null };
    }

    // Normal abandonment is Game Over: no Life refund.
    transaction.update(sessionRef, {
      status: 'ended',
      endedAt: FieldValue.serverTimestamp(),
      endReason: 'game_over',
    });

    if (current.activeGameSessionId === sessionId) {
      transaction.set(progress, {
        activeGameSessionId: FieldValue.delete(),
        activeGameChapterIndex: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    return { status: 'ended', life: null };
  });

  return {
    sessionId,
    status: finalStatus,
    life: transactionResult?.life ?? null,
    chapterProgress: settledChapterProgress,
  };
});