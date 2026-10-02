const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

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
    db.collection('users').doc(uid).get(),
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


exports.adminGetSecurityState = onCall(async (request) => {
  await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);

  const [authUser, enforcementSnapshot, riskSnapshot] = await Promise.all([
    getAuth().getUser(uid),
    db.collection('security_enforcement').doc(uid).get(),
    db.collection('security_risk_scores').doc(uid).get(),
  ]);

  const enforcement = enforcementSnapshot.data() || {};
  const risk = riskSnapshot.data() || {};

  return {
    ok: true,
    uid,
    authDisabled: authUser.disabled === true,
    enforcementStatus: enforcement.status || 'active',
    enforcementReason: enforcement.reason || null,
    lockedAt: enforcement.lockedAt?.toDate?.()?.toISOString?.() ?? null,
    restrictedUntil: enforcement.restrictedUntil?.toDate?.()?.toISOString?.() ?? null,
    riskScore: Number.isFinite(Number(risk.riskScoreTotal))
      ? Number(risk.riskScoreTotal)
      : 0,
    riskLevel: typeof risk.riskLevel === 'string' ? risk.riskLevel : 'NORMAL',
  };
});


exports.adminGetSecurityEvents = onCall(async (request) => {
  await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);
  const snapshot = await db.collection('security_events')
    .where('uid', '==', uid)
    .get();

  const events = snapshot.docs.map((doc) => {
      const event = doc.data() || {};
      return {
        eventId: event.eventId || doc.id,
        eventType: event.eventType || 'unknown',
        reason: event.reason || 'unspecified',
        severity: event.severity || 'WARNING',
        riskScore: Number.isFinite(Number(event.riskScore)) ? Number(event.riskScore) : 0,
        riskLevel: event.riskLevel || 'NORMAL',
        status: event.status || 'unknown',
        timestamp: event.timestamp?.toDate?.()?.toISOString?.() ?? null,
        toolType: event.toolType || null,
        details: event.details || {},
      };
    }).sort((a, b) => {
      const aTime = a.timestamp ? Date.parse(a.timestamp) : 0;
      const bTime = b.timestamp ? Date.parse(b.timestamp) : 0;
      return bTime - aTime;
    }).slice(0, 20);

  return { ok: true, uid, events };
});

exports.adminResetSecurityState = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);
  if (request.data?.confirm !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Security state reset requires explicit confirmation.',
    );
  }

  const enforcementRef = db.collection('security_enforcement').doc(uid);
  const riskRef = db.collection('security_risk_scores').doc(uid);

  await Promise.all([
    enforcementRef.set({
      status: 'active',
      reason: null,
      restrictedUntil: null,
      updatedAt: FieldValue.serverTimestamp(),
      clearedAt: FieldValue.serverTimestamp(),
      clearedBy: adminUid,
    }, { merge: true }),
    riskRef.set({
      riskScoreTotal: 0,
      riskLevel: 'NORMAL',
      lastEventScore: 0,
      lastEventRiskLevel: 'NORMAL',
      updatedAt: FieldValue.serverTimestamp(),
      clearedAt: FieldValue.serverTimestamp(),
      clearedBy: adminUid,
    }, { merge: true }),
  ]);

  return {
    ok: true,
    uid,
    enforcementStatus: 'active',
    riskScore: 0,
    riskLevel: 'NORMAL',
    changedBy: adminUid,
  };
});



exports.adminSetUnlockedChapter = onCall(async (request) => {
  const adminUid = await requireAdmin(request);
  const uid = validateTargetUid(request.data?.uid);
  const chapterIndex = request.data?.chapterIndex;

  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 || chapterIndex > 5) {
    throw new HttpsError('invalid-argument', 'chapterIndex must be between 0 and 5.');
  }

  const progressRef = db.collection('users').doc(uid)
    .collection('progress').doc('game');
  const snapshot = await progressRef.get();
  const current = snapshot.data() || {};
  const currentUnlocked = Number.isInteger(current.unlockedChapterIndex)
    ? Math.min(Math.max(current.unlockedChapterIndex, 0), 5)
    : 0;

  const unlockedChapterIndex = Math.max(currentUnlocked, chapterIndex);
  await progressRef.set({
    unlockedChapterIndex,
    updatedAt: FieldValue.serverTimestamp(),
    lastAdminAdjustmentBy: adminUid,
    lastAdminAdjustmentAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true, uid, unlockedChapterIndex, changedBy: adminUid };
});
