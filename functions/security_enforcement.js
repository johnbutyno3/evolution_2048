const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');

// Keep this module safe when Firebase Functions analyzes or loads it directly.
if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const RISK_LEVELS = new Set(['NORMAL', 'WARNING', 'ADMIN_ALERT', 'CRITICAL']);
const SENSITIVE_OPERATIONS = new Set([
  'purchase_tool',
  'use_tool',
  'spend_gold',
  'start_game_session',
  'resume_game_session',
  'restart_game_session',
  'abandon_game_session',
  'complete_chapter',
  'purchase',
  'grant_membership',
]);

function riskScoreRef(uid) {
  return db.collection('security_risk_scores').doc(uid);
}

function enforcementRef(uid) {
  return db.collection('security_enforcement').doc(uid);
}

function riskLevel(score) {
  if (score >= 100) return 'CRITICAL';
  if (score >= 60) return 'ADMIN_ALERT';
  if (score >= 30) return 'WARNING';
  return 'NORMAL';
}

function normalizeRiskLevel(value) {
  return RISK_LEVELS.has(value) ? value : 'NORMAL';
}

function isRestrictionActive(data) {
  if (data?.status === 'locked') return true;
  if (data?.status !== 'restricted') return false;
  const until = data.restrictedUntil;
  if (!until || typeof until.toMillis !== 'function') return true;
  return until.toMillis() > Date.now();
}

/**
 * Server-only gate for sensitive operations.
 * The cumulative risk score is authoritative; an optional explicit
 * restriction state can also block the operation until its expiry.
 */
async function enforceSensitiveOperation(uid, operation) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  if (!SENSITIVE_OPERATIONS.has(operation)) {
    throw new HttpsError('invalid-argument', 'Invalid security operation.');
  }

  const [riskSnapshot, enforcementSnapshot] = await Promise.all([
    riskScoreRef(uid).get(),
    enforcementRef(uid).get(),
  ]);

  const risk = riskSnapshot.data() || {};
  const enforcement = enforcementSnapshot.data() || {};
  const totalScore = Number(risk.riskScoreTotal) || 0;
  const derivedRiskLevel = riskLevel(totalScore);
  const storedRiskLevel = normalizeRiskLevel(risk.riskLevel);
  const effectiveRiskLevel = riskLevel(
    Math.max(totalScore, storedRiskLevel === 'CRITICAL' ? 100 : 0),
  );

  if (derivedRiskLevel === 'CRITICAL'
      || effectiveRiskLevel === 'CRITICAL'
      || isRestrictionActive(enforcement)) {
    throw new HttpsError(
      'permission-denied',
      'This operation is temporarily restricted for account security.',
    );
  }

  return {
    allowed: true,
    riskLevel: effectiveRiskLevel,
    status: enforcement.status || 'active',
  };
}

/**
 * Locks the account after a confirmed critical anti-cheat event. This function
 * is intended to be called by trusted server code only; Firestore rules must
 * prevent clients from writing this document.
 */
async function applyCriticalRestriction(uid, reason) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new Error('A valid uid is required.');
  }

  await enforcementRef(uid).set({
    status: 'locked',
    reason: typeof reason === 'string' && reason.length > 0
      ? reason
      : 'critical_security_risk',
    lockedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { status: 'locked' };
}

module.exports = {
  enforceSensitiveOperation,
  applyCriticalRestriction,
};
