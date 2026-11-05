'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { initializeApp, applicationDefault, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const CHAPTERS = [
  { legacyProgress: 'ocean', legacyCollection: 'ocean', code: 'C1', target: 4096 },
  { legacyProgress: 'land', legacyCollection: 'land', code: 'C2', target: 8192 },
  { legacyProgress: 'sky', legacyCollection: 'sky', code: 'C3', target: 16384 },
  { legacyProgress: 'history', legacyCollection: 'history', code: 'C4', target: 32768 },
  { legacyProgress: 'tech', legacyCollection: 'technology', code: 'C5', target: 65536 },
  { legacyProgress: 'universe', legacyCollection: 'space', code: 'C6', target: 131072 },
];

function canonicalize(value) {
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]),
    );
  }
  if (typeof value === 'bigint') return value.toString();
  return value;
}

function safeInteger(value, fallback = 0) {
  return Number.isSafeInteger(value) && value >= 0 ? value : fallback;
}

function isPowerOfTwo(value) {
  return Number.isSafeInteger(value) && value >= 2 && (value & (value - 1)) === 0;
}

function normalizeAccount(uid, source) {
  const errors = [];
  const user = source.user || {};
  const membershipSource = source.membership || {};
  const goldSource = source.gold || {};
  const toolsSource = source.tools || {};
  const lifeSource = source.life || {};
  const progressSource = source.gameProgress || {};
  const collectionSource = source.collection || {};

  const rawBalance = goldSource.balance ?? 0;
  if (!Number.isSafeInteger(rawBalance) || rawBalance < 0) {
    errors.push('invalid_gold_balance');
  }

  const rawLives = lifeSource.lives;
  const lives = Number.isSafeInteger(rawLives) && rawLives >= 0 && rawLives <= 5
    ? rawLives
    : (lifeSource.lives == null ? 5 : null);
  if (lives == null) errors.push('invalid_life_count');

  const toolMap = {
    UNDO: 'timeRewind',
    REMOVE: 'revive',
    SWAP: 'positionSwap',
    DUPLICATE: 'duplicate',
  };
  const tools = {};
  for (const [code, legacyKey] of Object.entries(toolMap)) {
    const raw = toolsSource[legacyKey] ?? 0;
    if (!Number.isSafeInteger(raw) || raw < 0) {
      errors.push(`invalid_tool_quantity:${code}`);
      tools[code] = 0;
    } else {
      tools[code] = raw;
    }
  }
  // Legacy ensureInitialUndo() grants one UNDO once unless it was already marked.
  if (toolsSource.initialUndoGranted !== true) {
    tools.UNDO = Math.max(tools.UNDO, 1);
  }

  const membershipType = String(membershipSource.type || '').toLowerCase();
  const expiry = membershipSource.expiresAt == null
    ? null
    : new Date(membershipSource.expiresAt);
  if (expiry && Number.isNaN(expiry.getTime())) errors.push('invalid_membership_expiry');
  const membershipActive = ['premium', 'golden'].includes(membershipType) &&
    (expiry == null || expiry.getTime() > Date.now());
  const tier = membershipActive ? membershipType.toUpperCase() : 'FREE';

  let nextRegenAt = null;
  if (lives != null && lives < 5) {
    const regenStart = lifeSource.regenStartAt == null
      ? null
      : new Date(lifeSource.regenStartAt);
    if (regenStart && Number.isNaN(regenStart.getTime())) {
      errors.push('invalid_life_regeneration_timestamp');
    } else if (regenStart) {
      nextRegenAt = new Date(regenStart.getTime() + 40 * 60 * 1000).toISOString();
      const delta = Date.parse(nextRegenAt) - Date.now();
      if (delta < -7 * 24 * 60 * 60 * 1000 || delta > 40 * 60 * 1000) {
        errors.push('life_regeneration_timestamp_out_of_window');
      }
    }
  }

  const chapters = [];
  for (const chapter of CHAPTERS) {
    const value = progressSource.chapterProgress?.[chapter.legacyProgress];
    if (!value) continue;
    const highestValue = safeInteger(value.highestValue, 0);
    const score = safeInteger(value.score, 0);
    if (highestValue !== 0 && (!isPowerOfTwo(highestValue) || highestValue > chapter.target)) {
      errors.push(`invalid_highest_value:${chapter.code}`);
      continue;
    }
    if (!Number.isSafeInteger(value.score) || value.score < 0) {
      errors.push(`invalid_best_score:${chapter.code}`);
      continue;
    }
    chapters.push({
      chapterCode: chapter.code,
      highestStage: highestValue === 0 ? 0 : Math.log2(highestValue),
      bestScore: score,
    });
  }

  const collection = [];
  for (const chapter of CHAPTERS) {
    const values = collectionSource[chapter.legacyCollection] ?? [];
    if (!Array.isArray(values)) {
      errors.push(`invalid_collection_array:${chapter.code}`);
      continue;
    }
    for (const value of values) {
      if (!isPowerOfTwo(value) || value > chapter.target) {
        errors.push(`invalid_collection_value:${chapter.code}:${String(value)}`);
        continue;
      }
      collection.push({ chapterCode: chapter.code, creatureValue: value });
    }
  }

  const avatarIndex = Number.isInteger(user.avatarIndex)
    ? Math.min(53, Math.max(0, user.avatarIndex))
    : 0;
  const normalized = {
    profile: {
      playerName: typeof user.playerName === 'string' ? user.playerName.trim().replace(/\\s+/g, ' ') : '',
      avatarIndex,
      accountStatus: ['locked', 'under_review'].includes(user.accountStatus)
        ? user.accountStatus
        : 'active',
    },
    membership: {
      tier,
      status: 'active',
      expiresAt: membershipActive && expiry ? expiry.toISOString() : null,
    },
    gold: { balance: Number.isSafeInteger(rawBalance) && rawBalance >= 0 ? rawBalance : 0 },
    lives: { count: lives ?? 5, nextRegenAt },
    tools,
    chapters,
    collection,
  };

  return { payload: normalized, validationErrors: errors };
}

async function listAllAuthUids(auth) {
  const uids = new Set();
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) uids.add(user.uid);
    pageToken = page.pageToken;
  } while (pageToken);
  return uids;
}

async function readDoc(ref) {
  const snapshot = await ref.get();
  return snapshot.exists ? snapshot.data() : null;
}

async function exportOne(uid, db) {
  const root = db.collection('users').doc(uid);
  const [user, membership, gold, tools, life, gameProgress, collection] = await Promise.all([
    readDoc(root),
    readDoc(root.collection('membership').doc('current')),
    readDoc(root.collection('wallet').doc('gold')),
    readDoc(root.collection('wallet').doc('tools')),
    readDoc(root.collection('life').doc('current')),
    readDoc(root.collection('progress').doc('game')),
    readDoc(root.collection('progress').doc('collection')),
  ]);
  const sourceRecord = canonicalize({
    user, membership, gold, tools, life, gameProgress, collection,
  });
  const sourceSha256 = crypto.createHash('sha256')
    .update(JSON.stringify(sourceRecord))
    .digest('hex');
  const normalized = normalizeAccount(uid, sourceRecord);
  return {
    legacyUid: uid,
    sourceSha256,
    sourceRecord,
    importPayload: normalized.payload,
    validationErrors: normalized.validationErrors,
  };
}

async function main() {
  const outputArg = process.argv[2];
  if (!outputArg) {
    throw new Error('Usage: node scripts/export_legacy_account_snapshot.js <new-output-file.json>');
  }
  const outputPath = path.resolve(outputArg);
  if (fs.existsSync(outputPath)) {
    throw new Error(`Refusing to overwrite existing export: ${outputPath}`);
  }
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Set GOOGLE_APPLICATION_CREDENTIALS to a restricted Firebase service-account JSON file.');
  }

  const app = getApps()[0] || initializeApp({ credential: applicationDefault() });
  const auth = getAuth(app);
  const db = getFirestore(app);
  const uids = await listAllAuthUids(auth);
  const firestoreUsers = await db.collection('users').get();
  for (const doc of firestoreUsers.docs) uids.add(doc.id);

  const accounts = [];
  let index = 0;
  for (const uid of uids) {
    index += 1;
    process.stdout.write(`Exporting account ${index}/${uids.size}\r`);
    accounts.push(await exportOne(uid, db));
  }
  process.stdout.write('\n');

  const exportDocument = {
    format: 'rebirth2048-firebase-account-export-v1',
    exportedAt: new Date().toISOString(),
    projectId: process.env.GCLOUD_PROJECT || app.options.projectId || null,
    accountCount: accounts.length,
    accounts,
  };

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(exportDocument, null, 2), {
    flag: 'wx',
    mode: 0o600,
  });
  process.stdout.write(`Export complete: ${accounts.length} accounts -> ${outputPath}\n`);
  process.stdout.write('Review validationErrors before importing. This file contains sensitive account data; keep it out of Git and shared folders.\n');
}

main().catch((error) => {
  process.stderr.write(`Export failed: ${error?.stack || error}\n`);
  process.exitCode = 1;
});
