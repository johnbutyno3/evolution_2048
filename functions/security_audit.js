const { FieldValue } = require('firebase-admin/firestore');
const { createAdminNotifications } = require('./admin_notifications');

const AUDIT_SEVERITIES = new Set([
  'WARNING',
  'SUSPICIOUS',
  'CONFIRMED',
  'CRITICAL',
]);

const RISK_RULES = [
  {
    score: 100,
    patterns: [
      'forged',
      'reused transaction',
      'transaction_reuse_detected',
      'authoritative data modification',
    ],
  },
  {
    score: 80,
    patterns: [
      'illegal_gold',
      'illegal gold',
    ],
  },
  {
    score: 50,
    patterns: [
      'illegal_tool',
      'illegal tool',
      'tool_inventory_invalid',
      'tool inventory invalid',
      'tool_not_allowed_for_chapter',
    ],
  },
  {
    score: 20,
    patterns: [
      'abnormal_frequency',
      'abnormal frequency',
      'repeated abnormal',
    ],
  },
  {
    score: 10,
    patterns: [
      'mismatch',
      'invalid_wallet_state',
    ],
  },
];

function normalizeAuditSeverity(severity) {
  const normalized = String(severity || 'warning').toUpperCase();

  if (normalized === 'HIGH') {
    return 'CONFIRMED';
  }

  return AUDIT_SEVERITIES.has(normalized) ? normalized : 'WARNING';
}

function calculateRiskScore(reason, details = {}) {
  const haystack = [
    typeof reason === 'string' ? reason : '',
    typeof details?.reason === 'string' ? details.reason : '',
    typeof details?.eventType === 'string' ? details.eventType : '',
  ].join(' ').toLowerCase();

  for (const rule of RISK_RULES) {
    if (rule.patterns.some((pattern) => haystack.includes(pattern))) {
      return rule.score;
    }
  }

  return 0;
}

function riskLevel(score) {
  if (score >= 100) return 'CRITICAL';
  if (score >= 60) return 'ADMIN_ALERT';
  if (score >= 30) return 'WARNING';
  return 'NORMAL';
}

async function applyCriticalRestrictionIfNeeded(db, uid) {
  const riskSnapshot = await db.collection('security_risk_scores').doc(uid).get();
  const totalScore = Number(riskSnapshot.data()?.riskScoreTotal) || 0;

  if (totalScore < 100) {
    return null;
  }

  const { applyCriticalRestriction } = require('./security_enforcement');
  return applyCriticalRestriction(uid, 'critical_security_risk');
}

function recordSecurityEvent(db, {
  uid,
  playerId = null,
  action,
  severity = 'warning',
  reason,
  details = {},
  clientValue = null,
  serverValue = null,
  productId = null,
  toolType = null,
  transactionId = null,
  requestId = null,
  platform = null,
  appVersion = null,
  status = 'rejected',
}) {
  const ref = db.collection('security_events').doc();
  const safeDetails = details && typeof details === 'object'
    ? details
    : {};

  const derivedClientValue = clientValue ?? safeDetails.clientValue ?? null;
  const derivedServerValue = serverValue ?? safeDetails.serverValue ?? null;
  const derivedProductId = productId ?? safeDetails.productId ?? null;
  const derivedToolType = toolType ?? safeDetails.toolType ?? null;
  const derivedTransactionId = transactionId ?? safeDetails.transactionId ?? null;
  const derivedRequestId = requestId ?? safeDetails.requestId ?? null;
  const derivedPlatform = platform ?? safeDetails.platform ?? null;
  const derivedAppVersion = appVersion ?? safeDetails.appVersion ?? null;
  const score = calculateRiskScore(reason, safeDetails);
  const normalizedSeverity = normalizeAuditSeverity(severity);
  const calculatedRiskLevel = riskLevel(score);

  const event = {
    eventId: ref.id,
    uid: typeof uid === 'string' ? uid : null,
    playerId: typeof playerId === 'string' ? playerId : null,
    eventType: typeof action === 'string' && action.length > 0
      ? action
      : 'unknown',
    severity: normalizedSeverity,
    reason: typeof reason === 'string' && reason.length > 0
      ? reason
      : 'unspecified',
    clientValue: derivedClientValue,
    serverValue: derivedServerValue,
    productId: derivedProductId,
    toolType: derivedToolType,
    transactionId: derivedTransactionId,
    requestId: derivedRequestId,
    platform: derivedPlatform,
    appVersion: derivedAppVersion,
    status,
    riskScore: score,
    riskLevel: calculatedRiskLevel,
    details: safeDetails,
  };

  const eventWrite = ref.set({
    ...event,
    timestamp: FieldValue.serverTimestamp(),
    auditSchemaVersion: 2,
  });

  const notificationWrite = calculatedRiskLevel === 'ADMIN_ALERT' || calculatedRiskLevel === 'CRITICAL'
    ? createAdminNotifications(db, event).catch(() => [])
    : Promise.resolve([]);

  if (typeof uid !== 'string' || uid.length === 0 || score <= 0) {
    return Promise.all([eventWrite, notificationWrite]).catch(() => null);
  }

  const riskRef = db.collection('security_risk_scores').doc(uid);
  const riskWrite = riskRef.set({
    uid,
    riskScoreTotal: FieldValue.increment(score),
    lastEventScore: score,
    lastEventRiskLevel: calculatedRiskLevel,
    lastEventId: ref.id,
    updatedAt: FieldValue.serverTimestamp(),
    riskSchemaVersion: 1,
  }, { merge: true });

  const enforcementWrite = riskWrite.then(() =>
    applyCriticalRestrictionIfNeeded(db, uid).catch(() => null),
  );

  return Promise.all([
    eventWrite,
    riskWrite,
    notificationWrite,
    enforcementWrite,
  ]).catch(() => null);
}

module.exports = {
  calculateRiskScore,
  normalizeAuditSeverity,
  recordSecurityEvent,
  riskLevel,
};
