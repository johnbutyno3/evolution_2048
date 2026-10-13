'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('node:crypto');
const domain = require('./domain');

initializeApp();
setGlobalOptions({ region: 'us-central1', enforceAppCheck: true });
const db = getFirestore();

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  return domain.requireUid(request.auth.uid);
}
function requestId(data) {
  const value = data && data.requestId;
  if (typeof value === 'string' && /^[A-Za-z0-9_-]{8,128}$/.test(value)) return value;
  throw new HttpsError('invalid-argument', 'A valid requestId is required.');
}
function playerRef(uid) { return db.collection('users').doc(uid); }
function lifeRef(uid) { return playerRef(uid).collection('wallet').doc('life'); }
function goldRef(uid) { return playerRef(uid).collection('wallet').doc('gold'); }
function toolsRef(uid) { return playerRef(uid).collection('wallet').doc('tools'); }
function membershipRef(uid) { return playerRef(uid).collection('membership').doc('current'); }
function sessionRef(uid, sessionId) { return playerRef(uid).collection('game_sessions').doc(sessionId); }
function callableError(error) {
  if (error instanceof HttpsError) throw error;
  if (error && error.code === 'invalid-argument') throw new HttpsError('invalid-argument', error.message);
  throw error;
}
async function membershipState(uid, nowMillis = Date.now()) {
  const snap = await membershipRef(uid).get();
  const data = snap.data() || {};
  const membership = domain.normalizeMembership(data.type || data.membership);
  const expiresAtMillis = data.expiresAt && typeof data.expiresAt.toMillis === 'function'
    ? data.expiresAt.toMillis() : (Number.isFinite(data.expiresAtMillis) ? data.expiresAtMillis : null);
  return { membership, expiresAtMillis, golden: domain.isGoldenMembership(membership, expiresAtMillis, nowMillis) };
}
async function getLifeState(uid, transaction = null) {
  const ref = lifeRef(uid);
  const snap = transaction ? await transaction.get(ref) : await ref.get();
  const data = snap.data() || {};
  const member = await membershipState(uid);
  const lives = Number.isSafeInteger(data.lives) && data.lives >= 0 ? data.lives : domain.NORMAL_LIFE_CAP;
  const nextLifeAtMillis = Number.isSafeInteger(data.nextLifeAtMillis) ? data.nextLifeAtMillis : null;
  const regen = member.golden ? { lives, nextLifeAtMillis: null }
    : domain.regenerateLives({ lives, nextLifeAtMillis, nowMillis: Date.now() });
  return { ref, data, member, state: domain.createLifeResponse({
    lives: regen.lives, membership: member.membership,
    expiresAtMillis: member.expiresAtMillis, nextLifeAtMillis: regen.nextLifeAtMillis,
  }) };
}
async function ensureWallet(uid) {
  const [lifeSnap, goldSnap, toolsSnap] = await Promise.all([lifeRef(uid).get(), goldRef(uid).get(), toolsRef(uid).get()]);
  const batch = db.batch();
  if (!lifeSnap.exists) batch.set(lifeRef(uid), { lives: domain.NORMAL_LIFE_CAP, nextLifeAtMillis: null, updatedAt: FieldValue.serverTimestamp() });
  if (!goldSnap.exists) batch.set(goldRef(uid), { balance: 0, lifetimeSpent: 0, updatedAt: FieldValue.serverTimestamp() });
  if (!toolsSnap.exists) batch.set(toolsRef(uid), { inventory: { revive: 0, timeRewind: 1, positionSwap: 0, duplicate: 0 }, updatedAt: FieldValue.serverTimestamp() });
  await batch.commit();
}

exports.getCallerIdentity = onCall(async (request) => {
  const uid = requireAuth(request);
  const snap = await playerRef(uid).get();
  return { uid, exists: snap.exists };
});

exports.getLifeState = onCall(async (request) => {
  const uid = requireAuth(request);
  await ensureWallet(uid);
  const result = await getLifeState(uid);
  if (!result.member.golden) {
    await result.ref.set({
      lives: result.state.lives,
      nextLifeAtMillis: result.state.nextLifeAtMillis,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  return result.state;
});

exports.consumeLife = onCall(async (request) => {
  const uid = requireAuth(request);
  const rid = requestId(request.data);
  await ensureWallet(uid);
  const receipt = playerRef(uid).collection('operation_receipts').doc('life_' + rid);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(receipt);
    if (existing.exists) return existing.data().result;
    const state = await getLifeState(uid, tx);
    if (state.member.golden) {
      tx.set(receipt, { result: state.state, createdAt: FieldValue.serverTimestamp() });
      return state.state;
    }
    const lives = state.state.lives;
    if (lives <= 0) throw new HttpsError('failed-precondition', 'No lives available.');
    const nextLives = lives - 1;
    const nextAt = nextLives < domain.NORMAL_LIFE_CAP
      ? (state.state.nextLifeAtMillis || Date.now() + domain.LIFE_REGEN_INTERVAL_MS) : null;
    const result = { ...state.state, lives: nextLives, infiniteLives: false, nextLifeAtMillis: nextAt };
    tx.set(state.ref, { lives: nextLives, nextLifeAtMillis: nextAt, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
    return result;
  });
});

exports.getGoldBalance = onCall(async (request) => {
  const uid = requireAuth(request);
  await ensureWallet(uid);
  const snap = await goldRef(uid).get();
  const data = snap.data() || {};
  return { balance: Number.isSafeInteger(data.balance) && data.balance >= 0 ? data.balance : 0,
    lifetimeSpent: Number.isSafeInteger(data.lifetimeSpent) && data.lifetimeSpent >= 0 ? data.lifetimeSpent : 0 };
});

exports.getToolInventory = onCall(async (request) => {
  const uid = requireAuth(request);
  await ensureWallet(uid);
  const snap = await toolsRef(uid).get();
  const data = snap.data() || {};
  const inventory = data.inventory || {};
  const normalized = Object.fromEntries(domain.TOOL_TYPES.map((type) => [type,
    Number.isSafeInteger(inventory[type]) && inventory[type] >= 0 ? inventory[type] : 0]));
  const member = await membershipState(uid);
  if (member.golden) normalized.timeRewind = Number.MAX_SAFE_INTEGER;
  return { inventory: normalized, allToolsEnabledForTest: false };
});

exports.purchaseTool = onCall(async (request) => {
  const uid = requireAuth(request);
  const rid = requestId(request.data);
  let type;
  let amount;
  try {
    type = domain.normalizeToolType(request.data && request.data.toolType);
    amount = domain.requireInteger(request.data && request.data.amount, 'amount', { min: 1, max: 50 });
  } catch (error) { callableError(error); }
  const prices = { revive: 100, timeRewind: 50, positionSwap: 200, duplicate: 500 };
  const price = prices[type] * amount;
  await ensureWallet(uid);
  const receipt = playerRef(uid).collection('operation_receipts').doc('purchase_' + rid);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(receipt);
    if (existing.exists) return existing.data().result;
    const wallet = await tx.get(goldRef(uid));
    const inventorySnap = await tx.get(toolsRef(uid));
    const walletData = wallet.data() || { balance: 0, lifetimeSpent: 0 };
    const inventoryData = inventorySnap.data() || { inventory: {} };
    if (!Number.isSafeInteger(walletData.balance) || walletData.balance < price) {
      throw new HttpsError('failed-precondition', 'Insufficient Gold.');
    }
    const inventory = { ...(inventoryData.inventory || {}) };
    const uses = (Number.isSafeInteger(inventory[type]) && inventory[type] >= 0 ? inventory[type] : 0) + amount;
    inventory[type] = uses;
    const result = { uses, balance: walletData.balance - price, lifetimeSpent: (walletData.lifetimeSpent || 0) + price };
    tx.set(goldRef(uid), { balance: result.balance, lifetimeSpent: result.lifetimeSpent, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(toolsRef(uid), { inventory, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
    return result;
  });
});

exports.consumeTool = onCall(async (request) => {
  const uid = requireAuth(request);
  const rid = requestId(request.data);
  const type = domain.normalizeToolType(request.data && request.data.toolType);
  await ensureWallet(uid);
  const receipt = playerRef(uid).collection('operation_receipts').doc('tool_' + rid);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(receipt);
    if (existing.exists) return existing.data().result;
    const inventorySnap = await tx.get(toolsRef(uid));
    const inventoryData = inventorySnap.data() || { inventory: {} };
    const inventory = { ...(inventoryData.inventory || {}) };
    const member = await membershipState(uid);
    if (member.golden && type === 'timeRewind') {
      const result = { toolType: type, uses: Number.MAX_SAFE_INTEGER };
      tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
      return result;
    }
    if (!Number.isSafeInteger(inventory[type]) || inventory[type] <= 0) {
      throw new HttpsError('failed-precondition', 'No uses remaining for this tool.');
    }
    inventory[type] -= 1;
    tx.set(toolsRef(uid), { inventory, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    const result = { toolType: type, uses: inventory[type] };
    tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
    return result;
  });
});

// Session/progression/profile/purchase verification/admin endpoints are added
// in subsequent migration commits. Deliberately not exported as placeholders:
// deploying an incomplete API would break existing Flutter clients.
