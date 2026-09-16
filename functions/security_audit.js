const { FieldValue } = require('firebase-admin/firestore');

const AUDIT_SEVERITIES = new Set([
  'WARNING',
  'SUSPICIOUS',
  'CONFIRMED',
  'CRITICAL',
]);

function normalizeAuditSeverity(severity) {
  const normalized = String(severity || 'warning').toUpperCase();

  if (normalized === 'HIGH') {
    return 'CONFIRMED';
  }

  return AUDIT_SEVERITIES.has(normalized) ? normalized : 'WARNING';
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

  return ref.set({
    eventId: ref.id,
    uid: typeof uid === 'string' ? uid : null,
    playerId: typeof playerId === 'string' ? playerId : null,
    eventType: typeof action === 'string' && action.length > 0
      ? action
      : 'unknown',
    severity: normalizeAuditSeverity(severity),
    reason: typeof reason === 'string' && reason.length > 0
      ? reason
      : 'unspecified',
    clientValue,
    serverValue,
    productId,
    toolType,
    transactionId,
    requestId,
    platform,
    appVersion,
    timestamp: FieldValue.serverTimestamp(),
    status,
    details: safeDetails,
    auditSchemaVersion: 1,
  }).catch(() => null);
}

module.exports = {
  normalizeAuditSeverity,
  recordSecurityEvent,
};
