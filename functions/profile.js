const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const crypto = require('crypto');

const db = getFirestore();
const MAX_AVATAR_INDEX = 53;
const PLAYER_NAME_MAX_LENGTH = 30;
const PLAYER_ID_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const COLLECTION_CHAPTER_KEYS = new Set([
  'ocean',
  'land',
  'sky',
  'history',
  'technology',
  'space',
]);
const COLLECTION_MAX_VALUE = 4096;

function normalizeName(name) {
  return name.trim().replace(/\s+/g, ' ').toLowerCase();
}

function validateName(name) {
  if (typeof name !== 'string') {
    throw new HttpsError('invalid-argument', 'Player name is required.');
  }

  const trimmed = name.trim().replace(/\s+/g, ' ');
  if (trimmed.length === 0 || trimmed.length > PLAYER_NAME_MAX_LENGTH ||
      trimmed.toUpperCase() === 'PLAYER') {
    throw new HttpsError('invalid-argument', 'Invalid player name.');
  }

  return trimmed;
}

function safeAvatarIndex(value) {
  if (!Number.isInteger(value)) return 0;
  return Math.min(Math.max(value, 0), MAX_AVATAR_INDEX);
}

function generatePlayerId() {
  const bytes = crypto.randomBytes(8);
  let value = '';
  for (const byte of bytes) {
    value += PLAYER_ID_CHARS[byte % PLAYER_ID_CHARS.length];
  }
  return `RB-${value}`;
}

async function generateUniquePlayerId(transaction) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const candidate = generatePlayerId();
    const ref = db.collection('player_ids').doc(candidate);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return { candidate, ref };
  }

  throw new HttpsError('resource-exhausted', 'Unable to allocate a player ID.');
}

async function generateUniqueName(transaction) {
  const base = 'Rebirther';

  for (let attempt = 0; attempt < 30; attempt += 1) {
    const suffix = 1000 + crypto.randomInt(0, 9000);
    const candidate = `${base}${suffix}`;
    const normalized = normalizeName(candidate);
    const ref = db.collection('player_names').doc(normalized);
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) return { candidate, normalized, ref };
  }

  throw new HttpsError('resource-exhausted', 'Unable to allocate a player name.');
}

exports.ensurePlayerProfile = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const uid = request.auth.uid;
  const userRef = db.collection('users').doc(uid);
  const requestedName = request.data?.playerName;
  const requestedAvatar = request.data?.avatarIndex;

  return db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    const data = userSnapshot.data() || {};

    let playerName = typeof data.playerName === 'string'
      ? data.playerName.trim().replace(/\s+/g, ' ')
      : '';
    let playerId = typeof data.playerId === 'string'
      ? data.playerId.trim()
      : '';
    let avatarIndex = safeAvatarIndex(data.avatarIndex);

    if (typeof requestedName === 'string' && requestedName.trim().length > 0) {
      playerName = validateName(requestedName);
    }

    if (Number.isInteger(requestedAvatar)) {
      avatarIndex = safeAvatarIndex(requestedAvatar);
    }

    let nameInfo;
    if (playerName.length === 0 || playerName.toLowerCase() === 'player') {
      nameInfo = await generateUniqueName(transaction);
      playerName = nameInfo.candidate;
    } else {
      const normalized = normalizeName(playerName);
      nameInfo = {
        candidate: playerName,
        normalized,
        ref: db.collection('player_names').doc(normalized),
      };
    }

    const existingName = await transaction.get(nameInfo.ref);
    const existingNameUid = existingName.data()?.uid;
    if (existingNameUid != null && existingNameUid !== uid) {
      throw new HttpsError('already-exists', 'Player name is already in use.');
    }

    let idInfo;
    if (playerId.length === 0) {
      idInfo = await generateUniquePlayerId(transaction);
      playerId = idInfo.candidate;
    } else {
      idInfo = {
        candidate: playerId,
        ref: db.collection('player_ids').doc(playerId),
      };
    }

    const existingId = await transaction.get(idInfo.ref);
    const existingIdUid = existingId.data()?.uid;
    if (existingIdUid != null && existingIdUid !== uid) {
      playerId = '';
      idInfo = await generateUniquePlayerId(transaction);
    }

    transaction.set(nameInfo.ref, {
      uid,
      playerName,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(idInfo.ref, {
      uid,
      playerId,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(userRef, {
      playerName,
      playerNameNormalized: nameInfo.normalized,
      playerId,
      avatarIndex,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      playerName,
      playerId,
      avatarIndex,
    };
  });
});

exports.updatePlayerProfile = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const uid = request.auth.uid;
  const userRef = db.collection('users').doc(uid);
  const newName = validateName(request.data?.playerName);

  return db.runTransaction(async (transaction) => {
    const userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'Player profile does not exist.');
    }

    const data = userSnapshot.data() || {};
    const oldNormalized = typeof data.playerNameNormalized === 'string'
      ? data.playerNameNormalized
      : (typeof data.playerName === 'string' ? normalizeName(data.playerName) : null);
    const normalized = normalizeName(newName);

    if (oldNormalized === normalized) {
      transaction.set(userRef, {
        playerName: newName,
        playerNameNormalized: normalized,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return {
        playerName: newName,
        playerId: data.playerId || null,
        avatarIndex: safeAvatarIndex(data.avatarIndex),
      };
    }

    const newNameRef = db.collection('player_names').doc(normalized);
    const existing = await transaction.get(newNameRef);
    const existingUid = existing.data()?.uid;
    if (existingUid != null && existingUid !== uid) {
      throw new HttpsError('already-exists', 'Player name is already in use.');
    }

    if (oldNormalized && oldNormalized !== normalized) {
      const oldNameRef = db.collection('player_names').doc(oldNormalized);
      transaction.delete(oldNameRef);
    }

    transaction.set(newNameRef, {
      uid,
      playerName: newName,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    transaction.set(userRef, {
      playerName: newName,
      playerNameNormalized: normalized,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      playerName: newName,
      playerId: data.playerId || null,
      avatarIndex: safeAvatarIndex(data.avatarIndex),
    };
  });
});

exports.updatePlayerAvatar = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const avatarIndex = safeAvatarIndex(request.data?.avatarIndex);
  const userRef = db.collection('users').doc(request.auth.uid);
  const snapshot = await userRef.get();

  if (!snapshot.exists) {
    throw new HttpsError('failed-precondition', 'Player profile does not exist.');
  }

  await userRef.set({
    avatarIndex,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { avatarIndex };
});

exports.discoverCreature = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const chapterKey = request.data?.chapterKey;
  const value = request.data?.value;

  if (typeof chapterKey !== 'string' || !COLLECTION_CHAPTER_KEYS.has(chapterKey)) {
    throw new HttpsError('invalid-argument', 'Invalid collection chapter.');
  }

  if (!Number.isInteger(value) || value < 2 || value > COLLECTION_MAX_VALUE ||
      (value & (value - 1)) !== 0) {
    throw new HttpsError('invalid-argument', 'Invalid creature value.');
  }

  const ref = db
    .collection('users')
    .doc(request.auth.uid)
    .collection('progress')
    .doc('collection');

  await ref.set({
    [chapterKey]: FieldValue.arrayUnion(value),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { chapterKey, value };
});

// Keep life callables in the existing Functions export surface.
Object.assign(exports, require('./life'));
