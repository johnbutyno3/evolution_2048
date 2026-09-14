const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');

initializeApp();
setGlobalOptions({ region: 'us-central1' });

const db = getFirestore();
const MAX_CHAPTER_INDEX = 5;

// Each chapter adds one evolution stage.
const STAGE_COUNTS = [12, 13, 14, 15, 16, 17];
const TARGETS = STAGE_COUNTS.map((stageCount) => 2 ** stageCount);

const PURCHASE_PROVIDERS = new Set(['google_play', 'apple']);
const MAX_SAFE_INTEGER = Number.MAX_SAFE_INTEGER;

function goldWalletRef(uid) {
  return db.collection('users').doc(uid).collection('wallet').doc('gold');
}

function validateGoldAmount(amount) {
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount > MAX_SAFE_INTEGER) {
    throw new HttpsError('invalid-argument', 'Amount must be a positive integer.');
  }
}

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
      throw new HttpsError('internal', 'Gold wallet data is invalid.');
    }
    if (balance < amount) {
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

exports.completeChapter = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'Authentication is required to update chapter progress.',
    );
  }

  const data = request.data || {};
  const chapterIndex = data.chapterIndex;
  const highestValue = data.highestValue;
  const score = data.score;

  if (!Number.isInteger(chapterIndex) ||
      chapterIndex < 0 ||
      chapterIndex > MAX_CHAPTER_INDEX) {
    throw new HttpsError('invalid-argument', 'Invalid chapter index.');
  }

  if (!Number.isInteger(highestValue) || highestValue < 0) {
    throw new HttpsError('invalid-argument', 'Invalid highest value.');
  }

  if (!Number.isInteger(score) || score < 0) {
    throw new HttpsError('invalid-argument', 'Invalid score.');
  }

  const uid = request.auth.uid;
  const progressRef = db
    .collection('users')
    .doc(uid)
    .collection('progress')
    .doc('game');

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(progressRef);
    const current = snapshot.data() || {};
    const currentUnlocked = Number.isInteger(current.unlockedChapterIndex)
      ? Math.min(Math.max(current.unlockedChapterIndex, 0), MAX_CHAPTER_INDEX)
      : 0;

    if (chapterIndex > currentUnlocked) {
      throw new HttpsError(
        'permission-denied',
        'Chapter is not unlocked.',
      );
    }

    // A chapter is complete only when its final evolution object appears.
    // The client cannot claim a later chapter's value to complete an earlier one.
    if (highestValue !== TARGETS[chapterIndex]) {
      throw new HttpsError(
        'failed-precondition',
        'The chapter final evolution stage has not been reached.',
      );
    }

    const nextUnlocked = Math.min(
      MAX_CHAPTER_INDEX,
      Math.max(currentUnlocked, chapterIndex + 1),
    );

    transaction.set(
      progressRef,
      {
        unlockedChapterIndex: nextUnlocked,
        [`chapter_${chapterIndex}_completed`]: true,
        [`chapter_${chapterIndex}_highestValue`]: highestValue,
        [`chapter_${chapterIndex}_bestScore`]: score,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { unlockedChapterIndex: nextUnlocked };
  });
});
