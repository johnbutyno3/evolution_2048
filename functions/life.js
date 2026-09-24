'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
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

function lifeRef(uid) {
  return db.collection('users').doc(uid).collection('life').doc('current');
}

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
}

async function readAndRegenerate(transaction, uid, membership) {
  const snapshot = await transaction.get(lifeRef(uid));
  const data = snapshot.data() || {};
  const nowMillis = Date.now();
  const lives = normalizeLives(data.lives);
  const regenStartMillis = normalizeRegenStart(data.regenStartAt);

  if (membership.infiniteLives) {
    return {
      lives: NORMAL_CAP,
      regenStartMillis: null,
      membership,
      regeneratedAmount: 0,
      previousLives: lives,
    };
  }

  const regenerated = regenerate({
    lives,
    regenStartMillis,
    nowMillis,
    interval: intervalMs(membership),
  });

  return {
    lives: regenerated.lives,
    regenStartMillis: regenerated.regenStartMillis,
    membership,
    regeneratedAmount: Math.max(0, regenerated.lives - lives),
    previousLives: lives,
  };
}

function writeLifeState(transaction, uid, lives, regenStartMillis) {
  transaction.set(lifeRef(uid), {
    lives,
    regenStartAt: regenStartMillis == null
      ? null
      : Timestamp.fromMillis(regenStartMillis),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function resolveServerState(transaction, uid) {
  const membershipSnapshot = await transaction.get(membershipRef(uid));
  const membership = resolveMembership(membershipSnapshot.data() || {});
  const current = await readAndRegenerate(transaction, uid, membership);

  writeLifeState(
    transaction,
    uid,
    current.lives,
    current.regenStartMillis,
  );

  if (current.regeneratedAmount > 0) {
    const eventRef = db
      .collection('users')
      .doc(uid)
      .collection('life_events')
      .doc();
    transaction.create(eventRef, {
      eventType: 'life_regeneration',
      amount: current.regeneratedAmount,
      beforeLives: current.previousLives,
      afterLives: current.lives,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return lifeResponse(
    current.lives,
    current.regenStartMillis,
    membership,
  );
}

exports.getLifeState = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  return db.runTransaction(async (transaction) => {
    return resolveServerState(transaction, request.auth.uid);
  });
});

exports.consumeLife = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const uid = request.auth.uid;

  return db.runTransaction(async (transaction) => {
    const membershipSnapshot = await transaction.get(membershipRef(uid));
    const membership = resolveMembership(membershipSnapshot.data() || {});
    const current = await readAndRegenerate(transaction, uid, membership);

    if (membership.infiniteLives) {
      writeLifeState(transaction, uid, NORMAL_CAP, null);
      return lifeResponse(NORMAL_CAP, null, membership);
    }

    if (current.lives <= 0) {
      throw new HttpsError('failed-precondition', 'No lives available.');
    }

    const nextLives = current.lives - 1;
    const regenStartMillis = nextLives < NORMAL_CAP
      ? (current.regenStartMillis ?? Date.now())
      : null;

    writeLifeState(transaction, uid, nextLives, regenStartMillis);

    return lifeResponse(nextLives, regenStartMillis, membership);
  });
});

exports.refundLife = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const uid = request.auth.uid;

  return db.runTransaction(async (transaction) => {
    const membershipSnapshot = await transaction.get(membershipRef(uid));
    const membership = resolveMembership(membershipSnapshot.data() || {});
    const current = await readAndRegenerate(transaction, uid, membership);

    if (membership.infiniteLives) {
      writeLifeState(transaction, uid, NORMAL_CAP, null);
      return lifeResponse(NORMAL_CAP, null, membership);
    }

    const nextLives = Math.min(NORMAL_CAP, Math.max(0, current.lives + 1));
    const regenStartMillis = nextLives >= NORMAL_CAP
      ? null
      : (current.regenStartMillis ?? Date.now());

    writeLifeState(transaction, uid, nextLives, regenStartMillis);

    return lifeResponse(nextLives, regenStartMillis, membership);
  });
});
