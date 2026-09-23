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

async function loadAndRegenerate(transaction, uid, membership) {
  const ref = lifeRef(uid);
  const snapshot = await transaction.get(ref);
  const data = snapshot.data() || {};
  const nowMillis = Date.now();
  const currentLives = normalizeLives(data.lives);
  const currentRegenStart = normalizeRegenStart(data.regenStartAt);

  if (membership.infiniteLives) {
    transaction.set(ref, {
      lives: NORMAL_CAP,
      regenStartAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return lifeResponse(NORMAL_CAP, null, membership);
  }

  const regenerated = regenerate({
    lives: currentLives,
    regenStartMillis: currentRegenStart,
    nowMillis,
    interval: intervalMs(membership),
  });

  transaction.set(ref, {
    lives: regenerated.lives,
    regenStartAt: regenerated.regenStartMillis == null
      ? null
      : Timestamp.fromMillis(regenerated.regenStartMillis),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return lifeResponse(
    regenerated.lives,
    regenerated.regenStartMillis,
    membership,
  );
}

async function resolveServerState(transaction, uid) {
  const membershipSnapshot = await transaction.get(membershipRef(uid));
  return loadAndRegenerate(
    transaction,
    uid,
    resolveMembership(membershipSnapshot.data() || {}),
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
  const ref = lifeRef(uid);

  return db.runTransaction(async (transaction) => {
    const membershipSnapshot = await transaction.get(membershipRef(uid));
    const membership = resolveMembership(membershipSnapshot.data() || {});
    const current = await loadAndRegenerate(transaction, uid, membership);

    if (membership.infiniteLives) return current;
    if (current.lives <= 0) {
      throw new HttpsError('failed-precondition', 'No lives available.');
    }

    const nextLives = current.lives - 1;
    const regenStartMillis = nextLives < NORMAL_CAP
      ? (current.nextLifeAtMillis == null
          ? Date.now()
          : current.nextLifeAtMillis - intervalMs(membership))
      : null;

    transaction.set(ref, {
      lives: nextLives,
      regenStartAt: regenStartMillis == null
        ? null
        : Timestamp.fromMillis(regenStartMillis),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return lifeResponse(nextLives, regenStartMillis, membership);
  });
});

exports.refundLife = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const uid = request.auth.uid;
  const ref = lifeRef(uid);

  return db.runTransaction(async (transaction) => {
    const membershipSnapshot = await transaction.get(membershipRef(uid));
    const membership = resolveMembership(membershipSnapshot.data() || {});
    const current = await loadAndRegenerate(transaction, uid, membership);

    if (membership.infiniteLives) return current;

    const nextLives = Math.min(NORMAL_CAP, Math.max(0, current.lives + 1));
    const regenStartMillis = nextLives >= NORMAL_CAP
      ? null
      : (current.nextLifeAtMillis == null
          ? Date.now()
          : current.nextLifeAtMillis - intervalMs(membership));

    transaction.set(ref, {
      lives: nextLives,
      regenStartAt: regenStartMillis == null
        ? null
        : Timestamp.fromMillis(regenStartMillis),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return lifeResponse(nextLives, regenStartMillis, membership);
  });
});
