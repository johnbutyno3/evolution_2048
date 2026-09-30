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
