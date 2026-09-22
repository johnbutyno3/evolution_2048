const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = getFirestore();

const NORMAL_CAP = 5;
const GENERAL_INTERVAL_MS = 60 * 60 * 1000;
const PREMIUM_INTERVAL_MS = 30 * 60 * 1000;
const MEMBERSHIP_TYPES = new Set(['premium', 'golden']);

function lifeRef(uid) {
  return db.collection('users').doc(uid).collection('life').doc('current');
}

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
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

function regenerationIntervalMs(membership) {
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

function calculateRegeneration({ lives, regenStartMillis, nowMillis, intervalMs }) {
  if (lives >= NORMAL_CAP) {
    return { lives, regenStartMillis: null };
  }

  const start = regenStartMillis ?? nowMillis;
  const elapsed = nowMillis - start;
  if (elapsed < intervalMs) {
    return { lives, regenStartMillis: start };
  }

  const recovered = Math.floor(elapsed / intervalMs);
  const nextLives = Math.min(NORMAL_CAP, lives + recovered);

  if (nextLives >= NORMAL_CAP) {
    return { lives: NORMAL_CAP, regenStartMillis: null };
  }

  return {
    lives: nextLives,
    regenStartMillis: start + recovered * intervalMs,
  };
}

function responseState({ lives, regenStartMillis, membership }) {
  if (membership.infiniteLives) {
    return {
      lives: -1,
      infiniteLives: true,
      lifeMode: 'golden',
      membership: membership.type,
      nextLifeAtMillis: null,
    };
  }

  if (lives >= NORMAL_CAP || regenStartMillis == null) {
    return {
      lives,
      infiniteLives: false,
      lifeMode: 'normal',
      membership: membership.type ?? 'general',
      nextLifeAtMillis: null,
    };
  }

  return {
    lives,
    infiniteLives: false,
    membership: membership.type ?? 'general',
    nextLifeAtMillis: regenStartMillis + regenerationIntervalMs(membership),
  };
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
    return responseState({
      lives: NORMAL_CAP,
      regenStartMillis: null,
      membership,
    });
  }

  const regenerated = calculateRegeneration({
    lives: currentLives,
    regenStartMillis: currentRegenStart,
    nowMillis,
    intervalMs: regenerationIntervalMs(membership),
  });

  transaction.set(ref, {
    lives: regenerated.lives,
    regenStartAt: regenerated.regenStartMillis == null
      ? null
      : Timestamp.fromMillis(regenerated.regenStartMillis),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return responseState({
    lives: regenerated.lives,
    regenStartMillis: regenerated.regenStartMillis,
    membership,
  });
}

async function resolveServerState(transaction, uid) {
  const membershipSnapshot = await transaction.get(membershipRef(uid));
  const membership = resolveMembership(membershipSnapshot.data() || {});
  return loadAndRegenerate(transaction, uid, membership);
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

    if (membership.infiniteLives) {
      return current;
    }

    if (current.lives <= 0) {
      throw new HttpsError('failed-precondition', 'No lives available.');
    }

    const nextLives = current.lives - 1;
    const regenStartMillis = nextLives < NORMAL_CAP
      ? (current.nextLifeAtMillis == null
          ? Date.now()
          : current.nextLifeAtMillis - regenerationIntervalMs(membership))
      : null;

    transaction.set(ref, {
      lives: nextLives,
      regenStartAt: regenStartMillis == null
        ? null
        : Timestamp.fromMillis(regenStartMillis),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return responseState({
      lives: nextLives,
      regenStartMillis,
      membership,
    });
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

    if (membership.infiniteLives) {
      return current;
    }

    const nextLives = Math.min(NORMAL_CAP, Math.max(0, current.lives + 1));
    const regenStartMillis = nextLives >= NORMAL_CAP
      ? null
      : (current.nextLifeAtMillis == null
          ? Date.now()
          : current.nextLifeAtMillis - regenerationIntervalMs(membership));

    transaction.set(ref, {
      lives: nextLives,
      regenStartAt: regenStartMillis == null
        ? null
        : Timestamp.fromMillis(regenStartMillis),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return responseState({
      lives: nextLives,
      regenStartMillis,
      membership,
    });
  });
});

