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
    const userSnapshot = await transaction.get(db.collection('users').doc(uid));
    const allToolsEnabledForTest = userSnapshot.data()?.allToolsEnabledForTest === true;
    const inventory = await ensureInitialUndo(transaction, uid, snapshot);
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

exports.purchaseTool = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'purchase_tool');

  const type = request.data?.toolType;
  const amount = request.data?.amount;
  validateToolType(type);
  validateToolAmount(amount);
  const membershipSnapshot = await membershipRef(request.auth.uid).get();
  const membership = resolveMembership(membershipSnapshot.data() || {});
  const membershipType = membership.type;
  const membershipActive = membership.active;

  // FREE members may purchase only the single-unit package.
  // Premium and Golden members may purchase all supported quantities.
  if (!membershipActive && amount !== 1) {
    throw new HttpsError(
      'failed-precondition',
      'FREE members can only purchase one tool at a time.',
    );
  }

  if (membershipActive &&
      membershipType === 'golden' &&
      type === 'timeRewind') {
    throw new HttpsError(
      'failed-precondition',
      'GOLDEN members have unlimited UNDO and do not need to purchase it.',
    );
  }

  const configSnapshot = await db.collection('shop_config').doc('global').get();
  const configuredPrice = configSnapshot.data()?.[toolPriceKey(type, amount)];
  const fallbackPrice = DEFAULT_TOOL_PRICES[toolPriceKey(type, amount)];
  const price = Number.isSafeInteger(configuredPrice)
    ? configuredPrice
    : fallbackPrice;
  if (!Number.isSafeInteger(price) || price <= 0) {
    throw new HttpsError('failed-precondition', 'Tool price is unavailable.');
  }

  const walletRef = goldWalletRef(request.auth.uid);
  const toolsRef = toolInventoryRef(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const walletSnapshot = await transaction.get(walletRef);
    const toolsSnapshot = await transaction.get(toolsRef);
    const balance = walletSnapshot.data()?.balance ?? 0;
    const inventory = toolsSnapshot.data() || {};
    const currentUses = inventory[type] ?? 0;

    if (!Number.isSafeInteger(balance) || balance < price ||
        !Number.isSafeInteger(currentUses) || currentUses < 0 ||
        currentUses > MAX_SAFE_INTEGER - amount) {
      if (balance < price) {
        await recordSecurityEvent({
          uid: request.auth.uid,
          action: 'purchase_tool',
          reason: 'insufficient_gold',
          details: { toolType: type, amount, price },
        });
      }
      throw new HttpsError('failed-precondition', 'Tool purchase is unavailable.');
    }

    transaction.set(walletRef, {
      balance: balance - price,
      lifetimeSpent: (walletSnapshot.data()?.lifetimeSpent ?? 0) + price,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    transaction.set(toolsRef, {
      [type]: currentUses + amount,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return { balance: balance - price, toolType: type, uses: currentUses + amount };
  });
});
