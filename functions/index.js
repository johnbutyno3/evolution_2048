const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');

initializeApp();
setGlobalOptions({ region: 'us-central1' });

const db = getFirestore();
const MAX_CHAPTER_INDEX = 5;
const GAME_SESSION_TTL_MS = 2 * 60 * 60 * 1000;

// Each chapter adds one evolution stage.
const STAGE_COUNTS = [12, 13, 14, 15, 16, 17];
const TARGETS = STAGE_COUNTS.map((stageCount) => 2 ** stageCount);

const PURCHASE_PROVIDERS = new Set(['google_play', 'apple']);
const MAX_SAFE_INTEGER = Number.MAX_SAFE_INTEGER;
const TOOL_TYPES = new Set(['revive', 'timeRewind', 'positionSwap', 'duplicate']);
const TOOL_AMOUNTS = new Set([1, 5, 20, 50]);
const MEMBERSHIP_TYPES = new Set(['premium', 'golden']);

function securityEventRef() {
  return db.collection('security_events').doc();
}

function recordSecurityEvent({ uid, action, severity = 'warning', reason, details = {} }) {
  return securityEventRef().set({
    uid: typeof uid === 'string' ? uid : null,
    action,
    severity,
    reason,
    details,
    createdAt: FieldValue.serverTimestamp(),
  }).catch(() => null);
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

function membershipRef(uid) {
  return db.collection('users').doc(uid).collection('membership').doc('current');
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

exports.getToolInventory = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const ref = toolInventoryRef(request.auth.uid);
  const snapshot = await ref.get();
  const inventory = snapshot.data() || {};
  return {
    inventory: Object.fromEntries(
      [...TOOL_TYPES].map((type) => [
        type,
        Number.isSafeInteger(inventory[type]) && inventory[type] >= 0
          ? inventory[type]
          : 0,
      ]),
    ),
  };
});

exports.purchaseTool = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const type = request.data?.toolType;
  const amount = request.data?.amount;
  validateToolType(type);
  validateToolAmount(amount);

  const configSnapshot = await db.collection('shop_config').doc('global').get();
  const price = configSnapshot.data()?.[toolPriceKey(type, amount)];
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

exports.useTool = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const type = request.data?.toolType;
  validateToolType(type);
  const ref = toolInventoryRef(request.auth.uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const inventory = snapshot.data() || {};
    const currentUses = inventory[type] ?? 0;
    if (!Number.isSafeInteger(currentUses) || currentUses <= 0) {
      await recordSecurityEvent({
        uid: request.auth.uid,
        action: 'use_tool',
        reason: 'tool_inventory_invalid_or_empty',
        details: { toolType: type, currentUses },
      });
      throw new HttpsError('failed-precondition', 'Tool is unavailable.');
    }

    const uses = currentUses - 1;
    transaction.set(ref, {
      [type]: uses,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { toolType: type, uses };
  });
});

exports.getMembershipStatus = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const snapshot = await membershipRef(request.auth.uid).get();
  const data = snapshot.data() || {};
  const type = MEMBERSHIP_TYPES.has(data.type) ? data.type : null;
  const expiresAt = data.expiresAt || null;
  const active = type !== null &&
    (expiresAt === null || expiresAt.toMillis() > Date.now());

  return {
    active,
    type: active ? type : null,
    expiresAt: active ? expiresAt : null,
    infiniteLives: active && type === 'golden',
    noAds: active,
  };
});

exports.grantMembership = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

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

exports.startGameSession = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const chapterIndex = request.data?.chapterIndex;
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
  const progressSnapshot = await progressRef.get();
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

  const sessionId = crypto.randomUUID();
  const startedAt = new Date();
  const expiresAt = new Date(startedAt.getTime() + GAME_SESSION_TTL_MS);
  const sessionRef = gameSessionRef(uid, sessionId);

  await sessionRef.create({
    chapterIndex,
    targetValue: TARGETS[chapterIndex],
    status: 'active',
    startedAt,
    expiresAt,
    createdAt: FieldValue.serverTimestamp(),
  });

  return {
    sessionId,
    chapterIndex,
    targetValue: TARGETS[chapterIndex],
    expiresAt: expiresAt.toISOString(),
  };
});

exports.completeChapter = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication is required to update chapter progress.',
    );
  }

  const data = request.data || {};
  const sessionId = data.sessionId;
  const chapterIndex = data.chapterIndex;
  const highestValue = data.highestValue;
  const score = data.score;

  if (typeof sessionId !== 'string' || sessionId.length < 16 || sessionId.length > 128) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'complete_chapter',
      severity: 'high',
      reason: 'invalid_game_session_id',
      details: { chapterIndex },
    });
    throw new HttpsError('invalid-argument', 'Invalid game session.');
  }

  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 ||
      chapterIndex > MAX_CHAPTER_INDEX) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'complete_chapter',
      reason: 'invalid_chapter_index',
      details: { chapterIndex },
    });
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }

  if (!Number.isInteger(highestValue) || highestValue < 0) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'complete_chapter',
      reason: 'invalid_highest_value',
      details: { chapterIndex, highestValue },
    });
    throw new HttpsError('invalid-argument', 'Invalid highest value.');
  }

  if (!Number.isSafeInteger(score) || score < 0) {
    await recordSecurityEvent({
      uid: request.auth.uid,
      action: 'complete_chapter',
      reason: 'invalid_score',
      details: { chapterIndex, score },
    });
    throw new HttpsError('invalid-argument', 'Invalid score.');
  }

  const uid = request.auth.uid;
  const sessionRef = gameSessionRef(uid, sessionId);
  const progressRef = db
    .collection('users')
    .doc(uid)
    .collection('progress')
    .doc('game');

  return db.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(sessionRef);
    const progressSnapshot = await transaction.get(progressRef);

    if (!sessionSnapshot.exists) {
      await recordSecurityEvent({
        uid,
        action: 'complete_chapter',
        severity: 'high',
        reason: 'game_session_not_found',
        details: { sessionId, chapterIndex },
      });
      throw new HttpsError('not-found', 'Game session was not found.');
    }

    const session = sessionSnapshot.data() || {};
    if (session.status !== 'active') {
      await recordSecurityEvent({
        uid,
        action: 'complete_chapter',
        severity: 'high',
        reason: 'game_session_replay',
        details: { sessionId, chapterIndex, status: session.status },
      });
      throw new HttpsError('failed-precondition', 'Game session is no longer active.');
    }

    if (session.chapterIndex !== chapterIndex ||
        session.targetValue !== TARGETS[chapterIndex]) {
      await recordSecurityEvent({
        uid,
        action: 'complete_chapter',
        severity: 'high',
        reason: 'game_session_mismatch',
        details: { sessionId, chapterIndex, sessionChapter: session.chapterIndex },
      });
      throw new HttpsError('failed-precondition', 'Game session does not match the chapter.');
    }

    const expiresAt = session.expiresAt?.toMillis?.() ?? 0;
    if (expiresAt <= Date.now()) {
      await recordSecurityEvent({
        uid,
        action: 'complete_chapter',
        severity: 'high',
        reason: 'game_session_expired',
        details: { sessionId, chapterIndex },
      });
      throw new HttpsError('deadline-exceeded', 'Game session has expired.');
    }

    const requiredTarget = TARGETS[chapterIndex];
    if (highestValue !== requiredTarget) {
      await recordSecurityEvent({
        uid,
        action: 'complete_chapter',
        severity: 'high',
        reason: 'completion_target_mismatch',
        details: { sessionId, chapterIndex, highestValue, requiredTarget },
      });
      throw new HttpsError(
        'failed-precondition',
        'Chapter completion target was not reached.',
      );
    }

    const current = progressSnapshot.data() || {};
    const currentUnlocked = Number.isInteger(current.unlockedChapterIndex)
      ? Math.min(Math.max(current.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;

    if (chapterIndex > currentUnlocked) {
      await recordSecurityEvent({
        uid,
        action: 'complete_chapter',
        severity: 'high',
        reason: 'locked_chapter_completion_attempt',
        details: { sessionId, chapterIndex, currentUnlocked },
      });
      throw new HttpsError(
        'permission-denied',
        'Chapter is not unlocked.',
      );
    }

    const nextUnlocked = Math.min(chapterIndex + 1, MAX_CHAPTER_INDEX);
    const currentHighest = Number.isInteger(current.highestValue)
      ? Math.max(current.highestValue, highestValue)
      : highestValue;
    const currentScore = Number.isSafeInteger(current.score)
      ? Math.max(current.score, score)
      : score;
    const unlockedChapterIndex = Math.max(currentUnlocked, nextUnlocked);

    transaction.set(progressRef, {
      unlockedChapterIndex,
      highestValue: currentHighest,
      score: currentScore,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.update(sessionRef, {
      status: 'completed',
      completedAt: FieldValue.serverTimestamp(),
      highestValue,
      score,
    });

    return {
      unlockedChapterIndex,
      highestValue: currentHighest,
      score: currentScore,
    };
  });
});
