const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { enforceSensitiveOperation } = require('./security_enforcement');
const { recordSecurityEvent } = require('./security_audit');
const { allowedToolsForChapter } = require('./replay_validator');

const db = getFirestore();
const TOOL_TYPES = ['revive', 'timeRewind', 'positionSwap', 'duplicate'];
const MAX_CHAPTER_INDEX = 5;

function inventoryRef(uid) {
  return db.collection('users').doc(uid).collection('wallet').doc('tools');
}

function sessionRef(uid, sessionId) {
  return db.collection('users').doc(uid).collection('game_sessions').doc(sessionId);
}

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
}

function resolveMembership(data) {
  const type = data?.type === 'premium' || data?.type === 'golden' ? data.type : null;
  const expiresAt = data?.expiresAt ?? null;
  const active = type !== null &&
      (expiresAt === null ||
        (typeof expiresAt.toMillis === 'function' && expiresAt.toMillis() > Date.now()));
  return { active, type: active ? type : null };
}

async function ensureInitialUndo(transaction, uid, snapshot) {
  const data = snapshot.data() || {};
  if (data.initialUndoGranted === true) return data;

  const undo = Number.isSafeInteger(data.timeRewind) && data.timeRewind >= 0
      ? data.timeRewind
      : 0;
  transaction.set(inventoryRef(uid), {
    timeRewind: Math.max(undo, 1),
    initialUndoGranted: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {...data, timeRewind: Math.max(undo, 1), initialUndoGranted: true};
}

exports.getToolInventory = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const uid = request.auth.uid;
  const ref = inventoryRef(uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const inventory = await ensureInitialUndo(transaction, uid, snapshot);
    const userSnapshot = await transaction.get(db.collection('users').doc(uid));
    const allToolsEnabledForTest = userSnapshot.data()?.allToolsEnabledForTest === true;
    return {
      allToolsEnabledForTest,
      inventory: Object.fromEntries(
        TOOL_TYPES.map((type) => [
          type,
          Number.isSafeInteger(inventory[type]) && inventory[type] >= 0 ? inventory[type] : 0,
        ]),
      ),
    };
  });
});

exports.useTool = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Authentication is required.');
  const uid = request.auth.uid;
  await enforceSensitiveOperation(uid, 'use_tool');

  const type = request.data?.toolType;
  const sessionId = request.data?.sessionId;
  if (!TOOL_TYPES.includes(type)) throw new HttpsError('invalid-argument', 'Invalid tool type.');
  if (typeof sessionId !== 'string' || sessionId.length === 0) {
    throw new HttpsError('invalid-argument', 'A game session is required.');
  }

  const session = sessionRef(uid, sessionId);
  const inventory = inventoryRef(uid);
  const membershipRefForUser = membershipRef(uid);

  return db.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(session);
    const inventorySnapshot = await transaction.get(inventory);
    const membershipSnapshot = await transaction.get(membershipRefForUser);

    if (!sessionSnapshot.exists || sessionSnapshot.data()?.status !== 'active') {
      throw new HttpsError('failed-precondition', 'Game session is not active.');
    }
    const sessionData = sessionSnapshot.data() || {};
    const expiresAt = sessionData.expiresAt;
    if (!expiresAt || typeof expiresAt.toMillis !== 'function' || expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('failed-precondition', 'Game session has expired.');
    }

    const chapterIndex = sessionData.chapterIndex;
    const userSnapshot = await transaction.get(db.collection('users').doc(uid));
    const allToolsEnabledForTest = userSnapshot.data()?.allToolsEnabledForTest === true;
    const allowedTools = allToolsEnabledForTest
      ? TOOL_TYPES
      : allowedToolsForChapter(chapterIndex);
    if (!Number.isInteger(chapterIndex) || chapterIndex < 0 || chapterIndex > MAX_CHAPTER_INDEX ||
        !allowedTools.includes(type)) {
      throw new HttpsError('failed-precondition', 'Tool is not available in this chapter.');
    }

    let data = inventorySnapshot.data() || {};
    if (data.initialUndoGranted !== true) {
      data = await ensureInitialUndo(transaction, uid, inventorySnapshot);
    }

    const membership = resolveMembership(membershipSnapshot.data() || {});
    const goldenUnlimitedUndo = membership.active && membership.type === 'golden' && type === 'timeRewind';
    const currentUses = Number.isSafeInteger(data[type]) ? data[type] : 0;

    if (!goldenUnlimitedUndo && currentUses <= 0) {
      throw new HttpsError('failed-precondition', 'Tool is unavailable.');
    }

    const uses = goldenUnlimitedUndo ? currentUses : currentUses - 1;
    const toolUsage = sessionData.toolUsage && typeof sessionData.toolUsage === 'object'
        ? {...sessionData.toolUsage}
        : {};
    const previousUsage = Number.isSafeInteger(toolUsage[type]) ? toolUsage[type] : 0;
    toolUsage[type] = previousUsage + 1;

    if (!goldenUnlimitedUndo) {
      transaction.set(inventory, {[type]: uses, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    }
    transaction.set(session, {toolUsage, updatedAt: FieldValue.serverTimestamp()}, {merge: true});

    return {toolType: type, uses, sessionId};
  });
});
