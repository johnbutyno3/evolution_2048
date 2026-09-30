const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const crypto = require('crypto');
const { replayGame, allowedToolsForChapter } = require('./replay_validator');
const { recordSecurityEvent: recordAuditEvent } = require('./security_audit');
const { enforceSensitiveOperation } = require('./security_enforcement');
const {
  NORMAL_CAP,
  MEMBERSHIP_TYPES,
  resolveMembership,
  intervalMs,
  normalizeLives,
  normalizeRegenStart,
  regenerate,
  lifeResponse,
} = require('./game_session_helpers');

initializeApp();
setGlobalOptions({ region: 'us-central1' });

const db = getFirestore();
Object.assign(exports, require('./profile'));
Object.assign(exports, require('./life'));
Object.assign(exports, require('./admin_test'));
Object.assign(exports, require('./tool_inventory_defaults'));

const MAX_CHAPTER_INDEX = 5;
const GAME_SESSION_TTL_MS = 2 * 60 * 60 * 1000;

// Each chapter adds one evolution stage.
const STAGE_COUNTS = [12, 13, 14, 15, 16, 17];
const TARGETS = STAGE_COUNTS.map((stageCount) => 2 ** stageCount);

const PURCHASE_PROVIDERS = new Set(['google_play', 'apple']);
const MAX_SAFE_INTEGER = Number.MAX_SAFE_INTEGER;
const TOOL_TYPES = new Set(['revive', 'timeRewind', 'positionSwap', 'duplicate']);
const TOOL_AMOUNTS = new Set([1, 5, 20, 50]);
const DEFAULT_TOOL_PRICES = {
  undo1Price: 50,
  undo5Price: 225,
  undo20Price: 700,
  undo50Price: 1500,
  remove1Price: 100,
  remove5Price: 450,
  remove20Price: 1400,
  remove50Price: 3000,
  swap1Price: 200,
  swap5Price: 900,
  swap20Price: 2800,
  swap50Price: 6000,
  duplicate1Price: 500,
  duplicate5Price: 2250,
  duplicate20Price: 7000,
  duplicate50Price: 15000,
};
function recordSecurityEvent({ uid, action, severity = 'warning', reason, details = {} }) {
  return recordAuditEvent(db, {
    uid,
    action,
    severity,
    reason,
    details,
  });
}

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
}

function goldWalletRef(uid) {
  return db.collection('users').doc(uid).collection('wallet').doc('gold');
}

function validateGoldAmount(amount) {
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > MAX_SAFE_INTEGER) {
    throw new HttpsError('invalid-argument', 'Amount must be a positive integer.');
  }
}

function toolInventoryRef(uid) {
  return db.collection('users').doc(uid).collection('wallet').doc('tools');
}

function chapterRewardTool(chapterIndex) {
  return [
    'timeRewind',
    'revive',
    'positionSwap',
    'duplicate',
    'duplicate',
    'timeRewind',
  ][chapterIndex] || null;
}

function chapterRewardTools(chapterIndex) {
  return [
    ['timeRewind'],
    ['timeRewind', 'revive'],
    ['timeRewind', 'revive', 'positionSwap'],
    ['timeRewind', 'revive', 'positionSwap', 'duplicate'],
    ['timeRewind', 'revive', 'positionSwap', 'duplicate'],
    ['timeRewind'],
  ][chapterIndex] || [];
}
function gameSessionRef(uid, sessionId) {
  return db.collection('users').doc(uid).collection('game_sessions').doc(sessionId);
}

function validateToolType(type) {
  if (!TOOL_TYPES.has(type)) {
    throw new HttpsError('invalid-argument', 'Invalid tool type.');
  }
}

function validateToolAmount(amount) {
  if (!Number.isInteger(amount) || !TOOL_AMOUNTS.has(amount)) {
    throw new HttpsError('invalid-argument', 'Invalid tool amount.');
  }
}

function toolPriceKey(type, amount) {
  const names = {
    revive: 'remove',
    timeRewind: 'undo',
    positionSwap: 'swap',
    duplicate: 'duplicate',
  };
  return `${names[type]}${amount}Price`;
}

exports.getMembershipStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const snapshot = await membershipRef(request.auth.uid).get();
  return resolveMembership(snapshot.data() || {});
});
exports.grantMembership = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'grant_membership');

  const callerSnapshot = await db.collection('users').doc(request.auth.uid).get();
  if (callerSnapshot.data()?.isAdmin !== true) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'grant_membership',
      severity: 'high',
      reason: 'unauthorized_admin_operation',
    });
    throw new HttpsError('permission-denied', 'Admin access is required.');
  }

  const uid = request.data?.uid;
  const type = request.data?.type;
  const durationDays = request.data?.durationDays;
  if (typeof uid !== 'string' || uid.length === 0 ||
      !MEMBERSHIP_TYPES.has(type) ||
      !Number.isInteger(durationDays) || durationDays <= 0 || durationDays > 3660) {
    throw new HttpsError('invalid-argument', 'Invalid membership grant.');
  }

  const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);
  await membershipRef(uid).set({
    type,
    expiresAt,
    grantedBy: request.auth.uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return {
    uid,
    type,
    expiresAt: expiresAt.toISOString(),
  };
});

exports.getGoldBalance = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const walletRef = goldWalletRef(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(walletRef);
    const balance = snapshot.data()?.balance ?? 0;
    const lifetimeSpent = snapshot.data()?.lifetimeSpent ?? 0;

    if (!Number.isSafeInteger(balance) || balance < 0 ||
        !Number.isSafeInteger(lifetimeSpent) || lifetimeSpent < 0) {
      await recordSecurityEvent({
        uid: request.auth.uid,
        action: 'get_gold_balance',
        severity: 'high',
        reason: 'invalid_wallet_state',
      });
      throw new HttpsError('internal', 'Gold wallet data is invalid.');
    }

    if (!snapshot.exists) {
      transaction.create(walletRef, {
        balance: 0,
        lifetimeSpent: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return { balance, lifetimeSpent };
  });
});

exports.spendGold = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'spend_gold');

  const amount = request.data?.amount;
  validateGoldAmount(amount);

  const walletRef = goldWalletRef(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(walletRef);
    const balance = snapshot.data()?.balance ?? 0;
    const lifetimeSpent = snapshot.data()?.lifetimeSpent ?? 0;

    if (!Number.isSafeInteger(balance) || balance < 0 ||
      !Number.isSafeInteger(lifetimeSpent) || lifetimeSpent < 0 ||
      lifetimeSpent > MAX_SAFE_INTEGER - amount) {
      await recordSecurityEvent({
        uid: request.auth.uid,
        action: 'spend_gold',
        severity: 'high',
        reason: 'invalid_wallet_state',
        details: { amount },
      });
      throw new HttpsError('internal', 'Gold wallet data is invalid.');
    }
    if (balance < amount) {
      await recordSecurityEvent({
        uid: request.auth.uid,
        action: 'spend_gold',
        reason: 'insufficient_gold',
        details: { amount, balance },
      });
      throw new HttpsError('failed-precondition', 'Not enough Gold.');
    }

    const nextBalance = balance - amount;
    transaction.set(walletRef, {
      balance: nextBalance,
      lifetimeSpent: lifetimeSpent + amount,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return { balance: nextBalance, lifetimeSpent: lifetimeSpent + amount };
  });
});

async function grantGoldToUser({
  uid,
  amount,
  source,
  purchaseId = null,
  transactionId = null,
}) {
  if (typeof uid !== 'string' || uid.length === 0) {
    throw new Error('A valid uid is required to grant Gold.');
  }

  validateGoldAmount(amount);

  if (typeof source !== 'string' || source.length === 0) {
    throw new Error('A grant source is required.');
  }

  const walletRef = goldWalletRef(uid);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(walletRef);
    const data = snapshot.data() || {};

    const balance = data.balance ?? 0;
    const lifetimeGranted = data.lifetimeGranted ?? 0;
    const lifetimeSpent = data.lifetimeSpent ?? 0;

    if (!Number.isSafeInteger(balance) || balance < 0 ||
        !Number.isSafeInteger(lifetimeGranted) || lifetimeGranted < 0 ||
        !Number.isSafeInteger(lifetimeSpent) || lifetimeSpent < 0) {
      throw new Error('Gold wallet data is invalid.');
    }

    if (balance > MAX_SAFE_INTEGER - amount ||
        lifetimeGranted > MAX_SAFE_INTEGER - amount) {
      throw new Error('Gold wallet limit exceeded.');
    }

    const nextBalance = balance + amount;
    const nextLifetimeGranted = lifetimeGranted + amount;

    transaction.set(walletRef, {
      balance: nextBalance,
      lifetimeGranted: nextLifetimeGranted,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      balance: nextBalance,
      lifetimeGranted: nextLifetimeGranted,
      amount,
      source,
      purchaseId,
      transactionId,
    };
  });
}
async function loadPurchasableProduct(productId) {
  if (typeof productId !== 'string' || productId.length === 0) {
    throw new HttpsError('invalid-argument', 'A productId is required.');
  }

  const snapshot = await db.collection('shop_config').doc('global').get();
  const products = snapshot.data()?.products;
  const product = products?.[productId];

  if (!product || product.active !== true ||
      !['gold', 'membership'].includes(product.type)) {
    throw new HttpsError('failed-precondition', 'Product is not available.');
  }

  if (typeof product.priceUsd !== 'number' || product.priceUsd <= 0) {
    throw new HttpsError('failed-precondition', 'Product price is invalid.');
  }

  if (product.type === 'gold' &&
      (!Number.isInteger(product.amount) || product.amount <= 0)) {
    throw new HttpsError('failed-precondition', 'Product amount is invalid.');
  }

  return {
    productId,
    type: product.type,
    amount: product.type === 'gold' ? product.amount : null,
    currency: typeof product.currency === 'string'
      ? product.currency
      : 'USD',
    priceUsd: product.priceUsd,
  };
}

function transactionKey(transactionId) {
  return crypto.createHash('sha256').update(transactionId).digest('hex');
}

exports.createPurchaseIntent = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication is required to create a purchase intent.',
    );
  }
  await enforceSensitiveOperation(request.auth.uid, 'purchase');

  const product = await loadPurchasableProduct(request.data?.productId);
  const uid = request.auth.uid;
  const purchaseRef = db
    .collection('users')
    .doc(uid)
    .collection('purchases')
    .doc();

  await purchaseRef.create({
    productId: product.productId,
    provider: 'pending',
    transactionId: null,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
    verifiedAt: null,
    grantedAt: null,
    amount: product.amount,
    currency: product.currency,
  });

  return {
    purchaseId: purchaseRef.id,
    productId: product.productId,
    status: 'pending',
    amount: product.amount,
    currency: product.currency,
  };
});

exports.submitPurchaseForVerification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication is required to submit a purchase for verification.',
    );
  }
  await enforceSensitiveOperation(request.auth.uid, 'purchase');

  const purchaseId = request.data?.purchaseId;
  const provider = request.data?.provider;
  const transactionId = request.data?.transactionId;

  if (typeof purchaseId !== 'string' || purchaseId.length === 0 ||
      typeof transactionId !== 'string' || transactionId.length === 0 ||
      !PURCHASE_PROVIDERS.has(provider)) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'submit_purchase_for_verification',
      reason: 'invalid_purchase_verification_data',
      details: { provider },
    });
    throw new HttpsError('invalid-argument', 'Invalid purchase verification data.');
  }

  const uid = request.auth.uid;
  const purchaseRef = db
    .collection('users')
    .doc(uid)
    .collection('purchases')
    .doc(purchaseId);
  const transactionRef = db
    .collection('purchase_transactions')
    .doc(transactionKey(transactionId));

  return db.runTransaction(async (transaction) => {
    const purchaseSnapshot = await transaction.get(purchaseRef);
    if (!purchaseSnapshot.exists) {
      await recordSecurityEvent({
        uid,
        action: 'submit_purchase_for_verification',
        reason: 'purchase_intent_not_found',
        details: { purchaseId, provider },
      });
      throw new HttpsError('not-found', 'Purchase intent was not found.');
    }

    const purchase = purchaseSnapshot.data();
    if (purchase.status !== 'pending') {
      return { purchaseId, status: purchase.status };
    }

    const transactionSnapshot = await transaction.get(transactionRef);
    if (transactionSnapshot.exists) {
      const existing = transactionSnapshot.data();
      if (existing.purchaseId !== purchaseId || existing.uid !== uid) {
        await recordSecurityEvent({
          uid,
          action: 'submit_purchase_for_verification',
          severity: 'high',
          reason: 'transaction_reuse_detected',
          details: { purchaseId, provider },
        });
        throw new HttpsError(
          'already-exists',
          'Transaction has already been associated with another purchase.',
        );
      }

      return { purchaseId, status: purchase.status };
    }

    transaction.create(transactionRef, {
      uid,
      purchaseId,
      provider,
      transactionId,
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.update(purchaseRef, {
      provider,
      transactionId,
      status: 'pending',
    });

    return { purchaseId, status: 'pending' };
  });
});

async function consumeLifeInTransaction(transaction, uid, membershipSnapshot = null) {
  const resolvedMembershipSnapshot = membershipSnapshot ??
    await transaction.get(membershipRef(uid));
  const membership = resolveMembership(resolvedMembershipSnapshot.data() || {});
  const lifeRef = db.collection('users').doc(uid).collection('life').doc('current');
  const lifeSnapshot = await transaction.get(lifeRef);
  const data = lifeSnapshot.data() || {};
  let lives = normalizeLives(data.lives);
  let regenStartMillis = normalizeRegenStart(data.regenStartAt);
  const nowMillis = Date.now();

  if (membership.infiniteLives) {
    transaction.set(lifeRef, {
      lives: NORMAL_CAP,
      regenStartAt: null,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return lifeResponse(-1, null, membership);
  }

  const regenerated = regenerate({
    lives,
    regenStartMillis,
    nowMillis,
    interval: intervalMs(membership),
  });
  lives = regenerated.lives;
  regenStartMillis = regenerated.regenStartMillis;

  if (lives <= 0) {
    throw new HttpsError('failed-precondition', 'No lives available.');
  }

  lives -= 1;
  const nextRegenStart = lives < NORMAL_CAP
    ? (regenStartMillis ?? nowMillis)
    : null;

  transaction.set(lifeRef, {
    lives,
    regenStartAt: nextRegenStart == null
      ? null
      : Timestamp.fromMillis(nextRegenStart),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return lifeResponse(lives, nextRegenStart, membership);
}

exports.startGameSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'start_game_session');

  const chapterIndex = request.data?.chapterIndex;
  const initialTiles = request.data?.initialTiles;
  if (!Array.isArray(initialTiles) ||
      initialTiles.length !== 16 ||
      initialTiles.filter((value) => value !== null).length !== 2 ||
      initialTiles.some((value) => value !== null && value !== 2 && value !== 4)) {
    throw new HttpsError(
      'invalid-argument',
      'A valid two-tile initial board is required.',
    );
  }
  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 ||
      chapterIndex > MAX_CHAPTER_INDEX) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'start_game_session',
      reason: 'invalid_chapter_index',
      details: { chapterIndex },
    });
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }

  const uid = request.auth.uid;
  const progressRef = db
    .collection('users')
    .doc(uid)
    .collection('progress')
    .doc('game');
  const toolsRef = toolInventoryRef(uid);
  const membershipDocRef = membershipRef(uid);

  const sessionId = crypto.randomUUID();
  const startedAt = new Date();
  const expiresAt = new Date(startedAt.getTime() + GAME_SESSION_TTL_MS);
  const sessionRef = gameSessionRef(uid, sessionId);

  const transactionLifeState = await db.runTransaction(async (transaction) => {
    const progressSnapshot = await transaction.get(progressRef);
    const toolsSnapshot = await transaction.get(toolsRef);
    const membershipSnapshot = await transaction.get(membershipDocRef);

    const current = progressSnapshot.data() || {};
    const currentUnlocked = Number.isInteger(current.unlockedChapterIndex)
      ? Math.min(Math.max(current.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;

    if (chapterIndex > currentUnlocked) {
      await recordSecurityEvent({
        uid,
        action: 'start_game_session',
        severity: 'high',
        reason: 'locked_chapter_session_attempt',
        details: { chapterIndex, currentUnlocked },
      });
      throw new HttpsError('permission-denied', 'Chapter is not unlocked.');
    }

    const replaceActiveSession = request.data?.replaceActiveSession === true;
    const existingSessionId = current.activeGameSessionId;
    let existingSessionRef = null;
    let existingSessionSnapshot = null;
    let existingSessionActive = false;
    if (typeof existingSessionId === 'string' && existingSessionId.length > 0) {
      existingSessionRef = gameSessionRef(uid, existingSessionId);
      existingSessionSnapshot = await transaction.get(existingSessionRef);
      existingSessionActive =
        existingSessionSnapshot.exists &&
        existingSessionSnapshot.data()?.status === 'active';

      if (existingSessionActive && !replaceActiveSession) {
        await recordSecurityEvent({
          uid,
          action: 'start_game_session',
          severity: 'high',
          reason: 'unfinished_active_session_exists',
          details: {
            chapterIndex,
            activeGameChapterIndex: current.activeGameChapterIndex,
            activeGameSessionId: existingSessionId,
          },
        });
        throw new HttpsError(
          'failed-precondition',
          'An unfinished game session already exists.',
        );
      }

      if (existingSessionActive &&
          current.activeGameChapterIndex !== chapterIndex) {
        throw new HttpsError(
          'failed-precondition',
          'An unfinished game session exists in another chapter.',
        );
      }

    }

    // Starting a genuinely new game attempt consumes exactly one Life.
    // This read/write must happen before any transaction write, because
    // Firestore transactions require all reads to precede writes.
    const consumedLifeState = await consumeLifeInTransaction(
      transaction,
      uid,
      membershipSnapshot,
    );

    if (typeof existingSessionId === 'string' && existingSessionId.length > 0) {
      if (existingSessionActive && replaceActiveSession) {
        transaction.update(existingSessionRef, {
          status: 'replaced',
          replacedAt: FieldValue.serverTimestamp(),
          replacedReason: 'fresh_entry_without_local_board',
        });
      }

      if (!existingSessionActive) {
        transaction.set(progressRef, {
          activeGameSessionId: FieldValue.delete(),
          activeGameChapterIndex: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    }

    // Chapter tool rewards are granted only by completeChapter after the
    // server has validated the completed replay. Starting a session must
    // never grant a reward merely for entering a chapter.

    transaction.create(sessionRef, {
      chapterIndex,
      targetValue: TARGETS[chapterIndex],
      status: 'active',
      startedAt,
      expiresAt,
      toolUsage: {},
      initialTiles: [...initialTiles],
      createdAt: FieldValue.serverTimestamp(),
    });

    transaction.set(progressRef, {
      activeGameSessionId: sessionId,
      activeGameChapterIndex: chapterIndex,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return consumedLifeState;
  });

  return {
    sessionId,
    chapterIndex,
    targetValue: TARGETS[chapterIndex],
    expiresAt: expiresAt.toISOString(),
    life: transactionLifeState,
  };
});

exports.resumeGameSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }
  await enforceSensitiveOperation(request.auth.uid, 'resume_game_session');

  const chapterIndex = request.data?.chapterIndex;
  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 ||
      chapterIndex > MAX_CHAPTER_INDEX) {
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }

  const uid = request.auth.uid;
  const progressRef = db.collection('users').doc(uid)
    .collection('progress').doc('game');
  let sessionId;

  await db.runTransaction(async (transaction) => {
    const progressSnapshot = await transaction.get(progressRef);

    const current = progressSnapshot.data() || {};
    sessionId = current.activeGameSessionId;
    const activeChapter = current.activeGameChapterIndex;

    if (typeof sessionId !== 'string' || sessionId.length === 0 ||
        activeChapter !== chapterIndex) {
      throw new HttpsError(
        'failed-precondition',
        'No matching unfinished game session is available to resume.',
      );
    }

    const sessionRef = gameSessionRef(uid, sessionId);
    const sessionSnapshot = await transaction.get(sessionRef);
    if (!sessionSnapshot.exists ||
        sessionSnapshot.data()?.status !== 'active') {
      throw new HttpsError(
        'failed-precondition',
        'The unfinished game session is no longer active.',
      );
    }

    const expiresAt = sessionSnapshot.data()?.expiresAt;
    if (!expiresAt ||
        typeof expiresAt.toMillis !== 'function' ||
        expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError(
        'deadline-exceeded',
        'Game session has expired.',
      );
    }

    // Resume is a continuation of the same server-owned board. The Life was
    // consumed when this session was originally created and remains owned by
    // this active board until Game Over, Restart, or Chapter Completion.
    transaction.set(sessionRef, {
      lastResumedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return null;
  });

  return {
    sessionId,
    chapterIndex,
    life: null,
  };
});

Object.assign(exports, require('./game_session'));

