const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { enforceSensitiveOperation } = require('./security_enforcement');
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
const STAGE_COUNTS = [12, 13, 14, 15, 16, 17];
const TARGETS = STAGE_COUNTS.map((stageCount) => 2 ** stageCount);
const CHAPTER_NAMES = ['ocean', 'land', 'sky', 'history', 'tech', 'universe'];

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

  const membership = resolveMembership(membershipSnapshot?.data() || {});
  const life = lifeRef(uid);
  const data = lifeSnapshot.data() || {};
  let lives = normalizeLives(data.lives);
  let regenStartMillis = normalizeRegenStart(data.regenStartAt);
  const nowMillis = Date.now();

  if (membership.infiniteLives) {
    transaction.set(life, {
      lives: NORMAL_CAP,
      regenStartAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return lifeResponse(-1, null, membership);
  }

  const regenerated = regenerate({
    lives,
    regenStartMillis,
    nowMillis,
    interval: intervalMs(membership),
  });

  const regeneratedAmount = Math.max(0, regenerated.lives - lives);
  if (regeneratedAmount > 0) {
    // This function runs inside a Firestore transaction, so retries must not
    // create duplicate life-regeneration audit events.
    const eventId = `regen_${regenStartMillis ?? 'none'}_${lives}_${regenerated.lives}`;
    transaction.create(
      db.collection('users').doc(uid).collection('life_events').doc(eventId),
      {
        eventType: 'life_regeneration',
        amount: regeneratedAmount,
        beforeLives: lives,
        afterLives: regenerated.lives,
        createdAt: FieldValue.serverTimestamp(),
      },
    );
  }

  lives = Math.min(NORMAL_CAP, regenerated.lives + 1);
  regenStartMillis = regenerated.regenStartMillis;
  if (lives >= NORMAL_CAP) regenStartMillis = null;

  transaction.set(life, {
    lives,
    regenStartAt: regenStartMillis == null
      ? null
      : Timestamp.fromMillis(regenStartMillis),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return lifeResponse(lives, regenStartMillis, membership);
}

exports.restartGameSession = onCall({ minInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'restart_game_session');

  const chapterIndex = request.data?.chapterIndex;
  const initialTiles = request.data?.initialTiles;
  if (!Array.isArray(initialTiles) ||
      initialTiles.length !== 16 ||
      initialTiles.filter((value) => value !== null).length !== 2 ||
      initialTiles.some((value) => value !== null && value !== 2 && value !== 4)) {
    throw new HttpsError(
      'invalid-argument',
      'A valid two-tile initial board is required.',
    );
  }
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
  const userRef = db.collection('users').doc(uid);
  const replayLog = request.data?.replayLog ?? null;

  try {
    return await db.runTransaction(async (transaction) => {
      const progressSnapshot = await transaction.get(progress);
      const currentProgress = progressSnapshot.data() || {};
      const oldSessionId = currentProgress.activeGameSessionId;
      const requestedSessionId = request.data?.sessionId;
      if (requestedSessionId != null &&
          (typeof requestedSessionId !== 'string' ||
           requestedSessionId !== oldSessionId)) {
        throw new HttpsError(
          'failed-precondition',
          'The active game session has changed.',
        );
      }
      const oldSessionRef = typeof oldSessionId === 'string' && oldSessionId.length > 0
        ? gameSessionRef(uid, oldSessionId)
        : null;

      const refs = [membership, life];
      if (oldSessionRef != null) refs.push(oldSessionRef);
      if (replayLog != null) {
        refs.push(userRef, toolInventoryRef(uid));
      }
      const snapshots = await transaction.getAll(...refs);
      const snapshotMap = new Map(refs.map((ref, index) => [ref.path, snapshots[index]]));
      const progressState = progressSnapshot;
      const membershipSnapshot = snapshotMap.get(membership.path);
      const lifeSnapshot = snapshotMap.get(life.path);
      const oldSessionSnapshot = oldSessionRef == null
        ? null
        : snapshotMap.get(oldSessionRef.path);

      const currentUnlocked = Number.isInteger(
        progressState.data()?.unlockedChapterIndex,
      )
        ? Math.min(
            Math.max(progressState.data().unlockedChapterIndex, 0),
            MAX_CHAPTER_INDEX,
          )
        : 0;

      if (chapterIndex > currentUnlocked) {
        throw new HttpsError('permission-denied', 'Chapter is not unlocked.');
      }

      const activeSessionIsValid =
        oldSessionSnapshot?.exists &&
        oldSessionSnapshot.data()?.status === 'active';
      if (activeSessionIsValid &&
          progressState.data()?.activeGameChapterIndex !== chapterIndex) {
        throw new HttpsError(
          'failed-precondition',
          'An unfinished game session exists in another chapter.',
        );
      }

      const membershipState = resolveMembership(membershipSnapshot.data() || {});
      let replayResult = null;
      if (replayLog != null && activeSessionIsValid) {
        const oldSession = oldSessionSnapshot.data() || {};
        const allToolsEnabledForTest =
          snapshotMap.get(userRef.path)?.data()?.allToolsEnabledForTest === true;
        try {
          replayResult = replayGame({
            replayLog,
            chapterIndex: oldSession.chapterIndex,
            targetValue: oldSession.targetValue,
            expectedInitialTiles: oldSession.initialTiles,
            allowedTools: allowedToolsForChapter(
              oldSession.chapterIndex,
              allToolsEnabledForTest,
            ),
            requireCompletion: false,
          });
        } catch (error) {
          const securityError = new Error(
            error?.message || 'Replay validation failed.',
          );
          securityError.securityReason = 'forged_replay_detected';
          securityError.securityDetails = {
            sessionId: oldSessionId,
            error: securityError.message,
          };
          throw securityError;
        }

        const previousUsage = oldSession.toolUsage &&
            typeof oldSession.toolUsage === 'object'
          ? oldSession.toolUsage
          : {};
        const inventory = snapshotMap.get(toolInventoryRef(uid).path)?.data() || {};
        const toolUpdates = {};

        for (const toolType of Object.keys(replayResult.toolUsage)) {
          const totalUses = replayResult.toolUsage[toolType] ?? 0;
          const settledUses = previousUsage[toolType] ?? 0;
          if (!Number.isSafeInteger(totalUses) || totalUses < 0 ||
              !Number.isSafeInteger(settledUses) || settledUses < 0 ||
              totalUses < settledUses) {
            const securityError = new Error('Tool usage does not match the active session.');
            securityError.securityReason = 'tool_usage_tampering_detected';
            securityError.securityDetails = {
              sessionId: oldSessionId, toolType, totalUses, settledUses,
            };
            throw securityError;
          }

          const delta = totalUses - settledUses;
          const goldenUnlimitedUndo = membershipState.active &&
              membershipState.type === 'golden' && toolType === 'timeRewind';
          if (delta === 0 || goldenUnlimitedUndo) continue;

          const currentUses = inventory[toolType] ?? 0;
          if (!Number.isSafeInteger(currentUses) || currentUses < delta) {
            const securityError = new Error('Tool inventory usage exceeded.');
            securityError.securityReason = 'tool_inventory_overuse_detected';
            securityError.securityDetails = {
              sessionId: oldSessionId, toolType, delta, currentUses,
            };
            throw securityError;
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

      const nextLives = membershipState.infiniteLives ? lives : lives - 1;
      const nextRegenStart = nextLives < NORMAL_CAP
        ? (regenStartMillis ?? nowMillis)
        : null;

      if (activeSessionIsValid) {
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
        initialTiles: [...(request.data?.initialTiles ?? [])],
        createdAt: FieldValue.serverTimestamp(),
        replacedSessionId: typeof oldSessionId === 'string' ? oldSessionId : null,
        replacedSessionChapterIndex: Number.isInteger(
          progressState.data()?.activeGameChapterIndex,
        )
          ? progressState.data().activeGameChapterIndex
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
  } catch (error) {
    if (error?.securityReason) {
      await recordSecurityEvent({
        uid,
        action: 'restart_game_session',
        severity: 'CRITICAL',
        reason: error.securityReason,
        details: error.securityDetails || {},
      });
      throw new HttpsError('permission-denied', 'Account security validation failed.');
    }
    throw error;
  }
});

exports.abandonGameSession = onCall({ minInstances: 1 }, async (request) => {
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
  const membership = membershipRef(uid);
  const userRef = db.collection('users').doc(uid);

  let finalStatus = 'ended';
  let settledChapterProgress = {};

  try {
    await db.runTransaction(async (transaction) => {
      // Read every document before any transaction write. Replay validation is
      // performed from this same snapshot so it cannot be detached from the
      // session that is actually being settled.
      const refs = [sessionRef, progress];
      if (unfinishedExit || replayLog != null) refs.push(membership);
      if (unfinishedExit) refs.push(lifeRef(uid));
      if (replayLog != null) refs.push(userRef, toolInventoryRef(uid));
      const snapshots = await transaction.getAll(...refs);
      const snapshotMap = new Map(
        refs.map((ref, index) => [ref.path, snapshots[index]]),
      );

      const sessionSnapshot = snapshotMap.get(sessionRef.path);
      const progressSnapshot = snapshotMap.get(progress.path);
      const membershipSnapshot = replayLog != null
        ? snapshotMap.get(membership.path)
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

      let replayResult = null;
      if (replayLog != null) {
        const allToolsEnabledForTest =
          snapshotMap.get(userRef.path)?.data()?.allToolsEnabledForTest === true;
        try {
          replayResult = replayGame({
            replayLog,
            chapterIndex: session.chapterIndex,
            targetValue: session.targetValue,
            expectedInitialTiles: session.initialTiles,
            allowedTools: allowedToolsForChapter(
              session.chapterIndex,
              allToolsEnabledForTest,
            ),
            requireCompletion: false,
          });
        } catch (error) {
          const securityError = new Error(
            error?.message || 'Replay validation failed.',
          );
          securityError.securityReason = 'forged_replay_detected';
          securityError.securityDetails = {
            sessionId,
            error: securityError.message,
          };
          throw securityError;
        }
      }

      if (replayResult != null) {
        const previousUsage = session.toolUsage &&
            typeof session.toolUsage === 'object'
          ? session.toolUsage
          : {};
        const inventory =
            snapshotMap.get(toolInventoryRef(uid).path)?.data() || {};
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
            const securityError = new Error(
              'Tool usage does not match the active session.',
            );
            securityError.securityReason = 'tool_usage_tampering_detected';
            securityError.securityDetails = {
              sessionId, toolType, totalUses, settledUses,
            };
            throw securityError;
          }

          const delta = totalUses - settledUses;
          const goldenUnlimitedUndo =
              membershipState.active &&
              membershipState.type === 'golden' &&
              toolType === 'timeRewind';

          if (delta === 0 || goldenUnlimitedUndo) continue;

          const currentUses = inventory[toolType] ?? 0;
          if (!Number.isSafeInteger(currentUses) || currentUses < delta) {
            const securityError = new Error(
              'Tool inventory usage exceeded.',
            );
            securityError.securityReason = 'tool_inventory_overuse_detected';
            securityError.securityDetails = {
              sessionId, toolType, delta, currentUses,
            };
            throw securityError;
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
        const settledHighest = Math.max(
          existingHighest,
          replayResult.highestValue,
        );
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
        if (current.activeGameSessionId !== sessionId) {
          throw new HttpsError(
            'failed-precondition',
            'Game session is not the current active game.',
          );
        }

        // Returning to Home refunds the Life consumed for this session.
        // The session is ended so the next explicit game entry creates a new
        // session and consumes exactly one Life again. The local board remains
        // available and is rebound to the new session by the Flutter client.
        const membershipSnapshotForRefund = snapshotMap.get(membership.path);
        const lifeSnapshotForRefund = snapshotMap.get(lifeRef(uid).path);
        const refundedLife = await refundLifeInTransaction(
          transaction,
          uid,
          membershipSnapshotForRefund,
          lifeSnapshotForRefund,
        );

        transaction.update(sessionRef, {
          status: 'ended',
          endedAt: FieldValue.serverTimestamp(),
          endReason: 'unfinished_exit',
          lastUnfinishedExitAt: FieldValue.serverTimestamp(),
        });
        transaction.set(progress, {
          activeGameSessionId: FieldValue.delete(),
          activeGameChapterIndex: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        finalStatus = 'ended';
        return {
          status: 'ended',
          life: refundedLife,
        };
      }

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
      life: null,
      chapterProgress: settledChapterProgress,
    };
  } catch (error) {
    if (error?.securityReason) {
      await recordSecurityEvent({
        uid,
        action: 'abandon_game_session',
        severity: 'CRITICAL',
        reason: error.securityReason,
        details: error.securityDetails || {},
      });
      throw new HttpsError(
        'permission-denied',
        'Account security validation failed.',
      );
    }
    throw error;
  }
});



/*
 * Clean gameplay lifecycle API.
 *
 * These two callables are intentionally separate from the legacy session
 * functions above. The Flutter game lifecycle uses only beginGame/finishGame:
 * the device starts and saves the board locally first; Firebase verifies the
 * important transition in the background.
 */
exports.beginGame = onCall({ minInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'begin_game');

  const uid = request.auth.uid;
  const gameId = request.data?.gameId;
  const chapterIndex = request.data?.chapterIndex;
  const initialTiles = request.data?.initialTiles;

  if (typeof gameId !== 'string' || gameId.length < 16 || gameId.length > 128) {
    throw new HttpsError('invalid-argument', 'Invalid game id.');
  }
  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 || chapterIndex > MAX_CHAPTER_INDEX) {
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }
  if (!Array.isArray(initialTiles) ||
      initialTiles.length !== 16 ||
      initialTiles.filter((value) => value !== null).length !== 2 ||
      initialTiles.some((value) => value !== null && value !== 2 && value !== 4)) {
    throw new HttpsError('invalid-argument', 'Invalid initial board.');
  }

  const progress = progressRef(uid);
  const life = lifeRef(uid);
  const membership = membershipRef(uid);
  const session = gameSessionRef(uid, gameId);

  return db.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(progress, life, membership, session);
    const progressSnapshot = snapshots[0];
    const lifeSnapshot = snapshots[1];
    const membershipSnapshot = snapshots[2];
    const sessionSnapshot = snapshots[3];

    if (sessionSnapshot.exists) {
      throw new HttpsError('already-exists', 'Game id already exists.');
    }

    const current = progressSnapshot.data() || {};
    const activeSessionId = current.activeGameSessionId;
    if (typeof activeSessionId === 'string' && activeSessionId.length > 0) {
      throw new HttpsError(
        'failed-precondition',
        'An active game already exists.',
      );
    }

    const unlocked = Number.isInteger(current.unlockedChapterIndex)
      ? Math.min(Math.max(current.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;
    if (chapterIndex > unlocked) {
      throw new HttpsError('permission-denied', 'Chapter is not unlocked.');
    }

    const membershipState = resolveMembership(
      membershipSnapshot.data() || {},
    );

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

    const nextLives = membershipState.infiniteLives ? lives : lives - 1;
    const nextRegenStart = nextLives < NORMAL_CAP
      ? (regenStartMillis ?? nowMillis)
      : null;

    transaction.set(life, {
      lives: nextLives,
      regenStartAt: nextRegenStart == null
        ? null
        : Timestamp.fromMillis(nextRegenStart),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(progress, {
      activeGameSessionId: gameId,
      activeGameChapterIndex: chapterIndex,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.create(session, {
      chapterIndex,
      targetValue: TARGETS[chapterIndex],
      status: 'active',
      initialTiles: [...initialTiles],
      startedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      gameId,
      chapterIndex,
      targetValue: TARGETS[chapterIndex],
      ...lifeResponse(nextLives, nextRegenStart, membershipState),
    };
  });
});

exports.finishGame = onCall({ minInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'finish_game');

  const uid = request.auth.uid;
  const gameId = request.data?.gameId;
  const reason = request.data?.reason;
  const chapterIndex = request.data?.chapterIndex;
  const highestValue = request.data?.highestValue;
  const score = request.data?.score;

  if (typeof gameId !== 'string' || gameId.length < 16 || gameId.length > 128) {
    throw new HttpsError('invalid-argument', 'Invalid game id.');
  }

  const allowedReasons = new Set(['abandoned', 'game_over', 'completed']);
  if (typeof reason !== 'string' || !allowedReasons.has(reason)) {
    throw new HttpsError('invalid-argument', 'Invalid finish reason.');
  }

  if (reason === 'completed' &&
      (!Number.isInteger(chapterIndex) ||
       chapterIndex < 0 || chapterIndex > MAX_CHAPTER_INDEX ||
       !Number.isSafeInteger(highestValue) ||
       !Number.isSafeInteger(score))) {
    throw new HttpsError('invalid-argument', 'Invalid completion data.');
  }

  const progress = progressRef(uid);
  const session = gameSessionRef(uid, gameId);

  return db.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(session, progress);
    const sessionSnapshot = snapshots[0];
    const progressSnapshot = snapshots[1];

    if (!sessionSnapshot.exists) {
      return { gameId, status: 'missing' };
    }

    const current = progressSnapshot.data() || {};
    const data = sessionSnapshot.data() || {};

    if (data.status !== 'active') {
      return { gameId, status: data.status || 'ended' };
    }

    if (reason === 'completed') {
      if (data.chapterIndex !== chapterIndex) {
        throw new HttpsError(
          'failed-precondition',
          'Game chapter does not match completion.',
        );
      }

      const requiredTarget = TARGETS[chapterIndex];
      if (highestValue < requiredTarget) {
        throw new HttpsError(
          'failed-precondition',
          'Chapter completion target was not reached.',
        );
      }

      const currentUnlocked = Number.isInteger(current.unlockedChapterIndex)
        ? Math.min(Math.max(current.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
        : 0;
      const nextUnlocked = Math.min(chapterIndex + 1, MAX_CHAPTER_INDEX);
      const chapterName = CHAPTER_NAMES[chapterIndex];
      const chapterProgress = current.chapterProgress &&
          typeof current.chapterProgress === 'object'
        ? current.chapterProgress
        : {};
      const oldChapter = chapterProgress[chapterName] || {};

      transaction.set(progress, {
        unlockedChapterIndex: Math.max(currentUnlocked, nextUnlocked),
        highestValue: Math.max(
          Number.isInteger(current.highestValue) ? current.highestValue : 0,
          highestValue,
        ),
        score: Math.max(
          Number.isSafeInteger(current.score) ? current.score : 0,
          score,
        ),
        chapterProgress: {
          [chapterName]: {
            highestValue: Math.max(
              Number.isInteger(oldChapter.highestValue) ? oldChapter.highestValue : 0,
              highestValue,
            ),
            score: Math.max(
              Number.isSafeInteger(oldChapter.score) ? oldChapter.score : 0,
              score,
            ),
            updatedAt: FieldValue.serverTimestamp(),
          },
        },
        activeGameSessionId: FieldValue.delete(),
        activeGameChapterIndex: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    } else if (current.activeGameSessionId === gameId) {
      transaction.set(progress, {
        activeGameSessionId: FieldValue.delete(),
        activeGameChapterIndex: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    const finalStatus = reason === 'completed'
      ? 'completed'
      : reason === 'game_over'
        ? 'game_over'
        : 'abandoned';

    transaction.update(session, {
      status: finalStatus,
      endedAt: FieldValue.serverTimestamp(),
      endReason: reason,
      ...(reason === 'completed'
        ? { highestValue, score }
        : {}),
    });

    return {
      gameId,
      status: finalStatus,
      ...(reason === 'completed'
        ? {
            unlockedChapterIndex: Math.min(
              MAX_CHAPTER_INDEX,
              Math.max(
                Number.isInteger(current.unlockedChapterIndex)
                  ? current.unlockedChapterIndex
                  : 0,
                chapterIndex + 1,
              ),
            ),
          }
        : {}),
    };
  });
});
