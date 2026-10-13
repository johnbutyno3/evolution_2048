'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const crypto = require('node:crypto');
const domain = require('./domain');
const { validateReplay } = require('./replay');

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
  // Legacy clients do not yet send requestId. Generate one for compatibility;
  // clients should migrate to stable IDs to make network retries idempotent.
  if (typeof value === 'string' && /^[A-Za-z0-9_-]{8,128}$/.test(value)) return value;
  return crypto.randomUUID();
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

exports.refundLife = onCall(async (request) => {
  const uid = requireAuth(request);
  await ensureWallet(uid);
  const progressRef = playerRef(uid).collection('progress').doc('game');
  return db.runTransaction(async (tx) => {
    const [progressSnap, lifeSnap, memberSnap] = await Promise.all([
      tx.get(progressRef), tx.get(lifeRef(uid)), tx.get(membershipRef(uid)),
    ]);
    const progress = progressSnap.data() || {};
    const completedSessionId = progress.lastCompletedSessionId;
    if (typeof completedSessionId !== 'string' || !completedSessionId) {
      throw new HttpsError('failed-precondition', 'No completed chapter is eligible for a life refund.');
    }
    const receipt = playerRef(uid).collection('operation_receipts').doc('refund_chapter_completion_' + completedSessionId);
    const receiptSnap = await tx.get(receipt);
    const memberData = memberSnap.data() || {};
    const membership = domain.normalizeMembership(memberData.type || memberData.membership);
    const expiresAtMillis = memberData.expiresAt && typeof memberData.expiresAt.toMillis === 'function'
      ? memberData.expiresAt.toMillis()
      : (Number.isFinite(memberData.expiresAtMillis) ? memberData.expiresAtMillis : null);
    const lifeData = lifeSnap.data() || { lives: domain.NORMAL_LIFE_CAP, nextLifeAtMillis: null };
    if (domain.isGoldenMembership(membership, expiresAtMillis)) {
      return domain.createLifeResponse({ lives: lifeData.lives, membership, expiresAtMillis });
    }
    // One refund per server-completed session. Retries are idempotent, while
    // later chapter completions can still refund their own entry Life.
    if (!receiptSnap.exists) {
      const lives = Number.isSafeInteger(lifeData.lives) && lifeData.lives >= 0
        ? lifeData.lives : domain.NORMAL_LIFE_CAP;
      const nextLives = Math.min(domain.NORMAL_LIFE_CAP, lives + 1);
      const nextAt = nextLives >= domain.NORMAL_LIFE_CAP
        ? null : (Number.isSafeInteger(lifeData.nextLifeAtMillis) ? lifeData.nextLifeAtMillis : Date.now() + domain.LIFE_REGEN_INTERVAL_MS);
      tx.set(lifeRef(uid), { lives: nextLives, nextLifeAtMillis: nextAt, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      tx.create(receipt, { createdAt: FieldValue.serverTimestamp() });
      return domain.createLifeResponse({ lives: nextLives, membership, expiresAtMillis, nextLifeAtMillis: nextAt });
    }
    return domain.createLifeResponse({
      lives: Number.isSafeInteger(lifeData.lives) ? lifeData.lives : domain.NORMAL_LIFE_CAP,
      membership, expiresAtMillis,
      nextLifeAtMillis: Number.isSafeInteger(lifeData.nextLifeAtMillis) ? lifeData.nextLifeAtMillis : null,
    });
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

exports.spendGold = onCall(async (request) => {
  const uid = requireAuth(request);
  const amount = domain.requireInteger(request.data && request.data.amount, 'amount', { min: 1, max: 100000000 });
  await ensureWallet(uid);
  const rid = requestId(request.data);
  const receipt = playerRef(uid).collection('operation_receipts').doc('spend_gold_' + rid);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(receipt);
    if (existing.exists) return existing.data().result;
    const walletSnap = await tx.get(goldRef(uid));
    const wallet = walletSnap.data() || { balance: 0, lifetimeSpent: 0 };
    const balance = Number.isSafeInteger(wallet.balance) && wallet.balance >= 0 ? wallet.balance : 0;
    const lifetimeSpent = Number.isSafeInteger(wallet.lifetimeSpent) && wallet.lifetimeSpent >= 0 ? wallet.lifetimeSpent : 0;
    if (balance < amount) throw new HttpsError('failed-precondition', 'Insufficient Gold.');
    const result = { balance: balance - amount, lifetimeSpent: lifetimeSpent + amount };
    tx.set(goldRef(uid), { ...result, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
    return result;
  });
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
  const packageAmounts = [1, 5, 20, 50];
  const priceTiers = {
    timeRewind: { 1: 50, 5: 225, 20: 700, 50: 1500 },
    revive: { 1: 100, 5: 450, 20: 1400, 50: 3000 },
    positionSwap: { 1: 200, 5: 900, 20: 2800, 50: 6000 },
    duplicate: { 1: 500, 5: 2250, 20: 7000, 50: 15000 },
  };
  if (!packageAmounts.includes(amount)) {
    throw new HttpsError('invalid-argument', 'Unsupported tool package amount.');
  }
  const member = await membershipState(uid);
  if (!member.golden && member.membership !== 'premium' && amount !== 1) {
    throw new HttpsError('failed-precondition', 'General members can only purchase one tool at a time.');
  }
  if (member.golden && type === 'timeRewind') {
    throw new HttpsError('failed-precondition', 'Golden membership includes unlimited UNDO.');
  }
  const price = priceTiers[type][amount];
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


exports.discoverCreature = onCall(async (request) => {
  const uid = requireAuth(request);
  const data = request.data || {};
  let chapterKey;
  let value;
  try {
    chapterKey = domain.normalizeChapterKey(data.chapterKey);
    value = domain.validateCreatureValue(data.value);
  } catch (error) { callableError(error); }
  const chapterLimit = { ocean: 4096, land: 8192, sky: 16384, history: 32768, technology: 65536, space: 131072 };
  // Collection discovery may record only creatures available by the player's
  // highest unlocked chapter; a client cannot populate future chapters.
  const progressRef = playerRef(uid).collection('progress').doc('game');
  const collectionRef = playerRef(uid).collection('progress').doc('collection');
  return db.runTransaction(async (tx) => {
    const [progressSnap, collectionSnap] = await Promise.all([tx.get(progressRef), tx.get(collectionRef)]);
    const progress = progressSnap.data() || {};
    const chapterIndex = { ocean: 0, land: 1, sky: 2, history: 3, technology: 4, space: 5 }[chapterKey];
    const unlocked = Number.isInteger(progress.unlockedChapterIndex) ? progress.unlockedChapterIndex : 0;
    if (chapterIndex > unlocked) throw new HttpsError('permission-denied', 'Chapter is locked.');
    if (value > chapterLimit[chapterKey]) throw new HttpsError('invalid-argument', 'Creature value exceeds this chapter limit.');
    const collection = collectionSnap.data() || {};
    const existing = Array.isArray(collection[chapterKey]) ? collection[chapterKey] : [];
    const values = [...new Set([...existing.filter((v) => Number.isSafeInteger(v)), value])].sort((a, b) => a - b);
    tx.set(collectionRef, { [chapterKey]: values, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    return { success: true, chapterKey, value, discoveredValues: values };
  });
});

exports.ensurePlayerProfile = onCall(async (request) => {
  const uid = requireAuth(request);
  const ref = playerRef(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set({
      playerId: crypto.randomUUID().slice(0, 12).toUpperCase(),
      playerName: null,
      avatarIndex: 0,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
  const current = (await ref.get()).data() || {};
  return {
    playerId: typeof current.playerId === 'string' ? current.playerId : uid.slice(0, 12),
    playerName: typeof current.playerName === 'string' ? current.playerName : null,
    avatarIndex: Number.isInteger(current.avatarIndex) ? current.avatarIndex : 0,
  };
});

exports.updatePlayerProfile = onCall(async (request) => {
  const uid = requireAuth(request);
  const rawName = request.data && request.data.playerName;
  if (typeof rawName !== 'string') throw new HttpsError('invalid-argument', 'Player name is required.');
  const playerName = rawName.trim().replace(/\\s+/g, ' ');
  if (!playerName || playerName.length > 30 || playerName.toUpperCase() === 'PLAYER') {
    throw new HttpsError('invalid-argument', 'Player name is invalid.');
  }
  const ref = playerRef(uid);
  await ref.set({ playerName, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  const data = (await ref.get()).data() || {};
  return { playerId: data.playerId || uid.slice(0, 12), playerName, avatarIndex: Number.isInteger(data.avatarIndex) ? data.avatarIndex : 0 };
});

exports.updatePlayerAvatar = onCall(async (request) => {
  const uid = requireAuth(request);
  const avatarIndex = request.data && request.data.avatarIndex;
  if (!Number.isInteger(avatarIndex) || avatarIndex < 0 || avatarIndex > 53) {
    throw new HttpsError('invalid-argument', 'Avatar index must be between 0 and 53.');
  }
  const ref = playerRef(uid);
  await ref.set({ avatarIndex, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  const data = (await ref.get()).data() || {};
  return { playerId: data.playerId || uid.slice(0, 12), playerName: data.playerName || null, avatarIndex };
});

exports.startGameSession = onCall(async (request) => {
  const uid = requireAuth(request);
  let chapterIndex;
  try { chapterIndex = domain.validateChapterIndex(request.data && request.data.chapterIndex); }
  catch (error) { callableError(error); }
  const rid = requestId(request.data);
  const replaceActiveSession = request.data && request.data.replaceActiveSession === true;
  const initialTiles = request.data && request.data.initialTiles;
  if (!Array.isArray(initialTiles) || initialTiles.length !== 16 ||
      initialTiles.some((value) => value !== null && value !== 2 && value !== 4) ||
      initialTiles.filter((value) => value !== null).length !== 2) {
    throw new HttpsError('invalid-argument', 'Initial board must contain exactly two 2/4 tiles and fourteen empty cells.');
  }
  await ensureWallet(uid);
  const receipt = playerRef(uid).collection('operation_receipts').doc('start_' + rid);
  const progressRef = playerRef(uid).collection('progress').doc('game');
  const sessionId = crypto.randomUUID();
  const newSessionRef = sessionRef(uid, sessionId);
  const result = await db.runTransaction(async (tx) => {
    const [priorReceipt, playerSnap, progressSnap, lifeSnap, memberSnap] = await Promise.all([
      tx.get(receipt), tx.get(playerRef(uid)), tx.get(progressRef), tx.get(lifeRef(uid)), tx.get(membershipRef(uid)),
    ]);
    if (priorReceipt.exists) return priorReceipt.data().result;
    const player = playerSnap.data() || {};
    const progress = progressSnap.data() || {};
    const activeId = progress.activeGameSessionId;
    if (activeId && !replaceActiveSession) {
      throw new HttpsError('failed-precondition', 'An unfinished game session already exists.');
    }
    const unlocked = Number.isInteger(progress.unlockedChapterIndex) ? progress.unlockedChapterIndex : 0;
    if (chapterIndex > unlocked) throw new HttpsError('permission-denied', 'Chapter is locked.');
    const life = lifeSnap.data() || { lives: domain.NORMAL_LIFE_CAP, nextLifeAtMillis: null };
    const member = memberSnap.data() || {};
    const membership = domain.normalizeMembership(member.type || member.membership);
    const expiresAtMillis = member.expiresAt && typeof member.expiresAt.toMillis === 'function'
      ? member.expiresAt.toMillis() : (Number.isFinite(member.expiresAtMillis) ? member.expiresAtMillis : null);
    const golden = domain.isGoldenMembership(membership, expiresAtMillis);
    const regen = golden ? { lives: life.lives ?? domain.NORMAL_LIFE_CAP, nextLifeAtMillis: null }
      : domain.regenerateLives({
        lives: Number.isSafeInteger(life.lives) && life.lives >= 0 ? life.lives : domain.NORMAL_LIFE_CAP,
        nextLifeAtMillis: Number.isSafeInteger(life.nextLifeAtMillis) ? life.nextLifeAtMillis : null,
      });
    if (!golden && regen.lives <= 0) throw new HttpsError('failed-precondition', 'No lives available.');
    const livesAfter = golden ? regen.lives : regen.lives - 1;
    const nextAt = golden ? null : (livesAfter < domain.NORMAL_LIFE_CAP
      ? (regen.nextLifeAtMillis || Date.now() + domain.LIFE_REGEN_INTERVAL_MS) : null);
    const lifeState = domain.createLifeResponse({
      lives: livesAfter, membership, expiresAtMillis, nextLifeAtMillis: nextAt,
    });
    const now = Timestamp.now();
    if (activeId && replaceActiveSession) {
      tx.set(sessionRef(uid, activeId), {
        status: 'replaced', closedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    tx.set(lifeRef(uid), { lives: livesAfter, nextLifeAtMillis: nextAt, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(newSessionRef, {
      uid, sessionId, chapterIndex, status: 'active',
      initialTiles, startedAt: now,
      expiresAt: Timestamp.fromMillis(now.toMillis() + domain.GAME_SESSION_TTL_MS),
      toolEvents: [],
    });
    tx.set(progressRef, { activeGameSessionId: sessionId, activeGameChapterIndex: chapterIndex, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    const response = { sessionId, chapterIndex, life: lifeState };
    tx.create(receipt, { result: response, createdAt: FieldValue.serverTimestamp() });
    return response;
  });
  return result;
});

exports.resumeGameSession = onCall(async (request) => {
  const uid = requireAuth(request);
  const sessionId = request.data && request.data.sessionId;
  if (typeof sessionId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(sessionId)) {
    throw new HttpsError('invalid-argument', 'Session ID is invalid.');
  }
  const snap = await sessionRef(uid, sessionId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'Game session was not found.');
  const session = snap.data();
  if (session.status !== 'active') throw new HttpsError('failed-precondition', 'Game session is not active.');
  if (session.expiresAt && session.expiresAt.toMillis() <= Date.now()) {
    throw new HttpsError('failed-precondition', 'Game session has expired.');
  }
  return { sessionId, chapterIndex: session.chapterIndex, initialTiles: session.initialTiles, startedAtMillis: session.startedAt.toMillis() };
});

exports.abandonGameSession = onCall(async (request) => {
  const uid = requireAuth(request);
  const sessionId = request.data && request.data.sessionId;
  const rid = requestId(request.data);
  if (typeof sessionId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(sessionId)) {
    throw new HttpsError('invalid-argument', 'Session ID is invalid.');
  }
  const receipt = playerRef(uid).collection('operation_receipts').doc('abandon_' + rid);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(receipt);
    if (existing.exists) return existing.data().result;
    const ref = sessionRef(uid, sessionId);
    const [sessionSnap, progressSnap] = await Promise.all([
      tx.get(ref), tx.get(playerRef(uid).collection('progress').doc('game')),
    ]);
    if (!sessionSnap.exists) throw new HttpsError('not-found', 'Game session was not found.');
    const session = sessionSnap.data();
    if (session.status === 'active') {
      tx.set(ref, { status: 'abandoned', closedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    const progress = progressSnap.data() || {};
    if (progress.activeGameSessionId === sessionId) {
      tx.set(playerRef(uid).collection('progress').doc('game'), {
        activeGameSessionId: FieldValue.delete(), activeGameChapterIndex: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    const result = { success: true, sessionId };
    tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
    return result;
  });
});

exports.completeChapter = onCall(async (request) => {
  const uid = requireAuth(request);
  const data = request.data || {};
  const sessionId = data.sessionId;
  let chapterIndex;
  try { chapterIndex = domain.validateChapterIndex(data.chapterIndex); }
  catch (error) { callableError(error); }
  if (typeof sessionId !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(sessionId)) {
    throw new HttpsError('invalid-argument', 'Session ID is invalid.');
  }
  if (!data.replayLog || typeof data.replayLog !== 'object') {
    throw new HttpsError('invalid-argument', 'A replayLog is required.');
  }
  // A completion receipt is keyed by the server-issued session ID, so repeated
  // completion calls cannot award progression twice even when the client retries.
  const receipt = playerRef(uid).collection('operation_receipts').doc('complete_' + sessionId);
  const progressRef = playerRef(uid).collection('progress').doc('game');
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(receipt);
    if (existing.exists) return existing.data().result;
    const ref = sessionRef(uid, sessionId);
    const [sessionSnap, progressSnap, toolsSnap, memberSnap] = await Promise.all([
      tx.get(ref), tx.get(progressRef), tx.get(toolsRef(uid)), tx.get(membershipRef(uid)),
    ]);
    if (!sessionSnap.exists) throw new HttpsError('not-found', 'Game session was not found.');
    const session = sessionSnap.data();
    if (session.status !== 'active' || session.chapterIndex !== chapterIndex) {
      throw new HttpsError('failed-precondition', 'Session is not eligible for completion.');
    }
    if (session.expiresAt && session.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError('failed-precondition', 'Game session has expired.');
    }
    const progress = progressSnap.data() || {};
    if (progress.activeGameSessionId !== sessionId) {
      throw new HttpsError('failed-precondition', 'Session is not the active player session.');
    }
    let replay;
    try {
      replay = validateReplay({
        replayLog: data.replayLog,
        chapterIndex,
        expectedInitialTiles: session.initialTiles,
        requireCompletion: true,
      });
    } catch (error) {
      throw new HttpsError('failed-precondition', 'Replay validation failed.', {
        reason: error.message,
        details: error.details || {},
      });
    }
    const memberData = memberSnap.data() || {};
    const membership = domain.normalizeMembership(memberData.type || memberData.membership);
    const expiresAtMillis = memberData.expiresAt && typeof memberData.expiresAt.toMillis === 'function'
      ? memberData.expiresAt.toMillis()
      : (Number.isFinite(memberData.expiresAtMillis) ? memberData.expiresAtMillis : null);
    const golden = domain.isGoldenMembership(membership, expiresAtMillis);
    const inventoryData = toolsSnap.data() || { inventory: {} };
    const inventory = { ...(inventoryData.inventory || {}) };
    for (const [toolType, count] of Object.entries(replay.toolUsage)) {
      if (count <= 0 || (golden && toolType === 'timeRewind')) continue;
      const available = Number.isSafeInteger(inventory[toolType]) && inventory[toolType] >= 0
        ? inventory[toolType] : 0;
      if (available < count) {
        throw new HttpsError('failed-precondition', 'Insufficient tool inventory for replay.', {
          toolType, available, used: count,
        });
      }
      inventory[toolType] = available - count;
    }
    const highestValue = replay.highestValue;
    const score = replay.score;
    const chapterNames = ['ocean', 'land', 'sky', 'history', 'tech', 'universe'];
    const chapterKey = chapterNames[chapterIndex];
    const chapterProgress = { ...(progress.chapterProgress || {}) };
    const previous = chapterProgress[chapterKey] || {};
    chapterProgress[chapterKey] = {
      highestValue: Math.max(Number.isSafeInteger(previous.highestValue) ? previous.highestValue : 0, highestValue),
      score: Math.max(Number.isSafeInteger(previous.score) ? previous.score : 0, score),
    };
    const unlockedChapterIndex = Math.min(5, Math.max(
      Number.isInteger(progress.unlockedChapterIndex) ? progress.unlockedChapterIndex : 0,
      chapterIndex < 5 ? chapterIndex + 1 : 5,
    ));
    const result = { success: true, unlockedChapterIndex, chapterProgress };
    tx.set(toolsRef(uid), { inventory, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    tx.set(ref, {
      status: 'completed', completedAt: FieldValue.serverTimestamp(),
      highestValue, score, replayEventCount: replay.eventCount,
      toolUsage: replay.toolUsage, toolPenaltyTotal: replay.toolPenaltyTotal,
    }, { merge: true });
    tx.set(progressRef, {
      chapterProgress, unlockedChapterIndex,
      lastCompletedSessionId: sessionId,
      activeGameSessionId: FieldValue.delete(), activeGameChapterIndex: FieldValue.delete(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.create(receipt, { result, createdAt: FieldValue.serverTimestamp() });
    return result;
  });
});
