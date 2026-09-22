const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const db = getFirestore();
const MEMBERSHIP_MODES = new Set(['general', 'premium', 'golden']);
const MAX_SAFE_INTEGER = Number.MAX_SAFE_INTEGER;

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
}

function goldWalletRef(uid) {
  return db.collection('users').doc(uid).collection('wallet').doc('gold');
}

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const callerSnapshot = await db.collection('users').doc(request.auth.uid).get();
  if (callerSnapshot.data()?.isAdmin !== true) {
    throw new HttpsError('permission-denied', 'Admin access is required.');
  }

  return request.auth.uid;
}

function validateTargetUid(value) {
  if (typeof value !== 'string' || value.length === 0 || value.length > 128) {
    throw new HttpsError('invalid-argument', 'A valid target uid is required.');
  }
  return value;
}

exports.adminSetMembershipMode = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);
  const mode = request.data?.mode;

  if (!MEMBERSHIP_MODES.has(mode)) {
    throw new HttpsError(
      'invalid-argument',
      'Membership mode must be general, premium, or golden.',
    );
  }

  const ref = membershipRef(uid);

  if (mode === 'general') {
    await ref.delete();
    return {
      ok: true,
      uid,
      mode: 'general',
      changedBy: adminUid,
    };
  }

  const durationDays = request.data?.durationDays ?? 30;
  if (!Number.isInteger(durationDays) ||
      durationDays < 1 ||
      durationDays > 3660) {
    throw new HttpsError(
      'invalid-argument',
      'durationDays must be between 1 and 3660.',
    );
  }

  const expiresAt = new Date(
    Date.now() + durationDays * 24 * 60 * 60 * 1000,
  );

  await ref.set({
    type: mode,
    expiresAt,
    changedBy: adminUid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    ok: true,
    uid,
    mode,
    expiresAt: expiresAt.toISOString(),
    changedBy: adminUid,
  };
});

exports.adminSetGoldBalance = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);
  const balance = request.data?.balance;

  if (!Number.isSafeInteger(balance) ||
      balance < 0 ||
      balance > MAX_SAFE_INTEGER) {
    throw new HttpsError(
      'invalid-argument',
      'balance must be a safe non-negative integer.',
    );
  }

  const ref = goldWalletRef(uid);
  const snapshot = await ref.get();
  const current = snapshot.data() || {};
  const lifetimeGranted = Number.isSafeInteger(current.lifetimeGranted) &&
      current.lifetimeGranted >= 0
    ? current.lifetimeGranted
    : 0;
  const lifetimeSpent = Number.isSafeInteger(current.lifetimeSpent) &&
      current.lifetimeSpent >= 0
    ? current.lifetimeSpent
    : 0;

  await ref.set({
    balance,
    lifetimeGranted,
    lifetimeSpent,
    updatedAt: FieldValue.serverTimestamp(),
    lastAdminAdjustmentBy: adminUid,
    lastAdminAdjustmentAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    ok: true,
    uid,
    balance,
    lifetimeGranted,
    lifetimeSpent,
    changedBy: adminUid,
  };
});


exports.adminSetAllToolsEnabled = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);
  const enabled = request.data?.enabled === true;

  await db.collection('users').doc(uid).set({
    allToolsEnabledForTest: enabled,
    updatedAt: FieldValue.serverTimestamp(),
    lastAdminAdjustmentBy: adminUid,
    lastAdminAdjustmentAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    ok: true,
    uid,
    allToolsEnabledForTest: enabled,
    changedBy: adminUid,
  };
});

exports.adminGetTestAccountState = onCall(async (request) => {
  await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);

  const [membershipSnapshot, goldSnapshot, userSnapshot] = await Promise.all([
    membershipRef(uid).get(),
    goldWalletRef(uid).get(),
  ]);

  const membership = membershipSnapshot.data() || {};
  const gold = goldSnapshot.data() || {};
  const user = userSnapshot.data() || {};

  let mode = 'general';
  if (membership.type === 'premium' || membership.type === 'golden') {
    const expiresAt = membership.expiresAt;
    const active = expiresAt == null ||
      (typeof expiresAt.toMillis === 'function' &&
        expiresAt.toMillis() > Date.now());
    if (active) mode = membership.type;
  }

  return {
    ok: true,
    uid,
    membershipMode: mode,
    expiresAt: membership.expiresAt?.toDate?.()?.toISOString?.() ?? null,
    goldBalance: Number.isSafeInteger(gold.balance) ? gold.balance : 0,
    allToolsEnabledForTest: user.allToolsEnabledForTest === true,
  };
});
