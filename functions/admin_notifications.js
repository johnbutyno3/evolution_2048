const { FieldValue } = require('firebase-admin/firestore');

const ADMIN_ROLE = 'admin';
const NOTIFICATION_SCHEMA_VERSION = 1;

function normalizeAdminUids(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.filter((uid) => typeof uid === 'string' && uid.trim().length > 0))];
}

function notificationPriority(riskLevel) {
  if (riskLevel === 'CRITICAL') return 'critical';
  if (riskLevel === 'ADMIN_ALERT') return 'high';
  return 'normal';
}

async function resolveAdminUids(db) {
  const snapshot = await db.collection('users').where('role', '==', ADMIN_ROLE).get();
  return normalizeAdminUids(snapshot.docs.map((doc) => doc.id));
}

async function createAdminNotifications(db, event) {
  const riskLevel = typeof event?.riskLevel === 'string' ? event.riskLevel : 'NORMAL';
  if (riskLevel !== 'ADMIN_ALERT' && riskLevel !== 'CRITICAL') return [];

  const adminUids = normalizeAdminUids(event.adminUids);
  const resolvedUids = adminUids.length > 0 ? adminUids : await resolveAdminUids(db);
  if (resolvedUids.length === 0) return [];

  const eventId = typeof event.eventId === 'string' ? event.eventId : null;
  const batch = db.batch();
  const notificationIds = [];

  for (const adminUid of resolvedUids) {
    const notificationRef = db
      .collection('users')
      .doc(adminUid)
      .collection('admin_notifications')
      .doc();

    notificationIds.push(notificationRef.id);
    batch.set(notificationRef, {
      notificationId: notificationRef.id,
      recipientUid: adminUid,
      eventId,
      eventType: event.eventType ?? event.action ?? null,
      severity: event.severity ?? 'warning',
      reason: event.reason ?? null,
      riskScore: Number.isFinite(event.riskScore) ? event.riskScore : 0,
      riskLevel,
      priority: notificationPriority(riskLevel),
      playerId: event.playerId ?? event.uid ?? null,
      transactionId: event.transactionId ?? null,
      productId: event.productId ?? null,
      toolType: event.toolType ?? null,
      requestId: event.requestId ?? null,
      details: event.details ?? {},
      read: false,
      createdAt: FieldValue.serverTimestamp(),
      schemaVersion: NOTIFICATION_SCHEMA_VERSION,
    });
  }

  await batch.commit();
  return notificationIds;
}

module.exports = {
  createAdminNotifications,
  notificationPriority,
  resolveAdminUids,
};
