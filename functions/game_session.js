const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const crypto = require('crypto');
const { enforceSensitiveOperation } = require('./security_enforcement');
const { recordSecurityEvent: recordAuditEvent } = require('./security_audit');

const db = getFirestore();
const MAX_CHAPTER_INDEX = 5;
const GAME_SESSION_TTL_MS = 2 * 60 * 60 * 1000;
const STAGE_COUNTS = [12, 13, 14, 15, 16, 17];
const TARGETS = STAGE_COUNTS.map((stageCount) => 2 ** stageCount);
const NORMAL_CAP = 5;
const GENERAL_INTERVAL_MS = 60 * 60 * 1000;
const PREMIUM_INTERVAL_MS = 30 * 60 * 1000;
const MEMBERSHIP_TYPES = new Set(['premium', 'golden']);

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

function resolveMembership(data) {
  const type = MEMBERSHIP_TYPES.has(data?.type) ? data.type : null;
  const expiresAt = data?.expiresAt ?? null;
  let active = false;

  if (type !== null) {
    if (expiresAt === null) {
      active = true;
    } else if (typeof expiresAt.toMillis === 'function') {
      active = expiresAt.toMillis() > Date.now();
    }
  }

  return {
    active,
    type: active ? type : null,
    infiniteLives: active && type === 'golden',
  };
}

function intervalMs(membership) {
  return membership.type === 'premium'
    ? PREMIUM_INTERVAL_MS
    : GENERAL_INTERVAL_MS;
}

function normalizeLives(value) {
  return Number.isSafeInteger(value) && value >= 0 ? value : NORMAL_CAP;
}

function normalizeRegenStart(value) {
  if (!value || typeof value.toMillis !== 'function') return null;
  return value.toMillis();
}

function regenerate({ lives, regenStartMillis, nowMillis, interval }) {
  if (lives >= NORMAL_CAP) {
    return { lives: NORMAL_CAP, regenStartMillis: null };
  }

  const start = regenStartMillis ?? nowMillis;
  const elapsed = nowMillis - start;
  if (elapsed < interval) {
    return { lives, regenStartMillis: start };
  }

  const recovered = Math.floor(elapsed / interval);
  const nextLives = Math.min(NORMAL_CAP, lives + recovered);
  if (nextLives >= NORMAL_CAP) {
    return { lives: NORMAL_CAP, regenStartMillis: null };
  }

  return {
    lives: nextLives,
    regenStartMillis: start + recovered * interval,
  };
}

function lifeResponse(lives, regenStartMillis, membership) {
  if (membership.infiniteLives) {
    return {
      lives: -1,
      infiniteLives: true,
      membership: membership.type,
      nextLifeAtMillis: null,
    };
  }

  if (lives >= NORMAL_CAP || regenStartMillis == null) {
    return {
      lives,
      infiniteLives: false,
      membership: membership.type ?? 'general',
      nextLifeAtMillis: null,
    };
  }

  return {
    lives,
    infiniteLives: false,
    membership: membership.type ?? 'general',
    nextLifeAtMillis: regenStartMillis + intervalMs(membership),
  };
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

  return db.runTransaction(async (transaction) => {
    const progressSnapshot = await transaction.get(progress);
    const membershipSnapshot = await transaction.get(membership);
    const lifeSnapshot = await transaction.get(life);

    const currentProgress = progressSnapshot.data() || {};
    const currentUnlocked = Number.isInteger(currentProgress.unlockedChapterIndex)
      ? Math.min(Math.max(currentProgress.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;

    if (chapterIndex > currentUnlocked) {
      throw new HttpsError('permission-denied', 'Chapter is not unlocked.');
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

    const nextLives = membershipState.infiniteLives ? lives : lives - 1;
    const nextRegenStart = nextLives < NORMAL_CAP
      ? (regenStartMillis ?? nowMillis)
      : null;

    const oldSessionId = currentProgress.activeGameSessionId;
    const oldSessionChapter = currentProgress.activeGameChapterIndex;

    if (typeof oldSessionId === 'string' && oldSessionId.length > 0) {
      const oldSessionRef = gameSessionRef(uid, oldSessionId);
      const oldSessionSnapshot = await transaction.get(oldSessionRef);
      if (oldSessionSnapshot.exists && oldSessionSnapshot.data()?.status === 'active') {
        transaction.update(oldSessionRef, {
          status: 'replaced',
          replacedAt: FieldValue.serverTimestamp(),
        });
      }
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