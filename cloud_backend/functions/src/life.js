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

  const regeneratedAmount = Math.max(0, regenerated.lives - lives);
  if (regeneratedAmount > 0) {
    // Firestore transactions may retry their callback. Use a deterministic
    // event ID derived from the exact life transition so a retry cannot
    // create duplicate regeneration events for the same committed change.
    const eventId = `regen_${regenStartMillis ?? 'none'}_${lives}_${regenerated.lives}`;
    const eventRef = db
      .collection('users')
      .doc(uid)
      .collection('life_events')
      .doc(eventId);
    transaction.create(eventRef, {
      eventType: 'life_regeneration',
      amount: regeneratedAmount,
      beforeLives: lives,
      afterLives: regenerated.lives,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  return {
    lives: regenerated.lives,
    regenStartMillis: regenerated.regenStartMillis,
    membership,
    regeneratedAmount,
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
