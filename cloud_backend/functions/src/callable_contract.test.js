'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repoRoot = path.resolve(__dirname, '../../..');
const frontendFiles = [
  'lib/services/player_progress_service.dart',
  'lib/game/services/life_manager.dart',
  'lib/game/services/gold_manager.dart',
  'lib/game/services/tool_manager.dart',
];
const frontendCallables = new Set();

for (const relativePath of frontendFiles) {
  const filePath = path.join(repoRoot, relativePath);
  const source = fs.readFileSync(filePath, 'utf8');
  const pattern = /httpsCallable\s*\(\s*['"]([^'"]+)['"]\s*\)/g;
  for (const match of source.matchAll(pattern)) {
    frontendCallables.add(match[1]);
  }
}

const sourceDir = __dirname;
const backendCallables = new Set();
for (const name of fs.readdirSync(sourceDir)) {
  if (!name.endsWith('.js') || name.endsWith('.test.js')) continue;
  const source = fs.readFileSync(path.join(sourceDir, name), 'utf8');
  const pattern = /exports\.([A-Za-z0-9_]+)\s*=\s*onCall\s*\(/g;
  for (const match of source.matchAll(pattern)) {
    backendCallables.add(match[1]);
  }
}

const missing = [...frontendCallables].filter((name) => !backendCallables.has(name));
assert.deepEqual(
  missing,
  [],
  `Frontend calls missing backend callable exports: ${missing.join(', ')}`,
);
console.log(`Callable contract OK: ${frontendCallables.size} frontend callables have backend exports.`);

const lifeSource = fs.readFileSync(path.join(sourceDir, 'life.js'), 'utf8');
assert.doesNotMatch(
  lifeSource,
  /exports\\.refundLife\\s*=\\s*onCall\\s*\\(/,
  'Life refunds must only occur in a server-authorized transactional game flow.',
);
console.log('Life refund safety contract OK: no public refundLife callable.');

// Safety contract: accepting a client transaction ID must never itself grant
// currency or membership. Until trusted provider verification exists, this
// endpoint must only record a pending verification request.
const indexSource = fs.readFileSync(path.join(sourceDir, 'index.js'), 'utf8');
const purchaseStart = indexSource.indexOf('exports.submitPurchaseForVerification = onCall(');
const purchaseEnd = indexSource.indexOf(
  '\nasync function consumeLifeInTransaction',
  purchaseStart,
);
assert.notEqual(purchaseStart, -1, 'Purchase verification callable must exist.');
assert.notEqual(purchaseEnd, -1, 'Purchase verification callable boundary must exist.');
const purchaseCallable = indexSource.slice(purchaseStart, purchaseEnd);
assert.match(purchaseCallable, /status:\s*'pending'/);
assert.doesNotMatch(
  purchaseCallable,
  /grantGoldToUser\s*\(|membershipRef\([^)]*\)\.set\s*\(/,
  'Client-submitted transaction IDs must not grant Gold or membership.',
);
assert.match(
  purchaseCallable,
  /transaction\.create\(transactionRef/,
  'Purchase transaction IDs must be reserved against replay.',
);
console.log('Purchase verification safety contract OK: client submission remains pending only.');

// Guard the core server idempotency invariants against accidental removal.
const goldSpendStart = indexSource.indexOf('exports.spendGold = onCall(');
const goldSpendEnd = indexSource.indexOf('\nasync function grantGoldToUser', goldSpendStart);
assert.notEqual(goldSpendStart, -1, 'Gold spend callable must exist.');
const goldSpend = indexSource.slice(goldSpendStart, goldSpendEnd);
assert.match(goldSpend, /gold_spend_operations/);
assert.match(goldSpend, /transaction\.get\(receiptRef\)/);
assert.match(goldSpend, /transaction\.create\(receiptRef/);
assert.match(goldSpend, /receipt\.amount !== amount/);

const toolSource = fs.readFileSync(path.join(sourceDir, 'tool_inventory_defaults.js'), 'utf8');
const toolPurchaseStart = toolSource.indexOf('exports.purchaseTool = onCall(');
const toolPurchase = toolSource.slice(toolPurchaseStart);
assert.notEqual(toolPurchaseStart, -1, 'Tool purchase callable must exist.');
assert.match(toolPurchase, /tool_purchase_operations/);
assert.match(toolPurchase, /transaction\.get\(receiptRef\)/);
assert.match(toolPurchase, /transaction\.create\(receiptRef/);
assert.match(toolPurchase, /receipt\.toolType !== type \|\| receipt\.amount !== amount/);
console.log('Idempotency safety contract OK: Gold spend and tool purchase receipts are transactionally enforced.');

const restartSource = fs.readFileSync(path.join(sourceDir, 'game_session.js'), 'utf8');
assert.match(restartSource, /createRestartOperationContext/);
assert.match(restartSource, /transaction\.get\(operationRef\)/);
assert.match(restartSource, /transaction\.create\(operationRef/);
assert.match(restartSource, /restartFingerprintMatches/);
const progressSource = fs.readFileSync(
  path.join(repoRoot, 'lib/services/player_progress_service.dart'),
  'utf8',
);
assert.match(progressSource, /'operationId': operationId/);
assert.match(progressSource, /PendingOperationStore\.getOrCreate/);
console.log('RESET idempotency contract OK: client key, server receipt, and payload fingerprint are wired.');


const indexConfig = JSON.parse(
  fs.readFileSync(path.join(repoRoot, 'firestore.indexes.json'), 'utf8'),
);
const securityEventIndex = indexConfig.indexes.find((index) =>
  index.collectionGroup === 'security_events' &&
  index.fields.some((field) => field.fieldPath === 'uid' && field.order === 'ASCENDING') &&
  index.fields.some((field) => field.fieldPath === 'timestamp' && field.order === 'DESCENDING'),
);
assert.ok(
  securityEventIndex,
  'Admin security event history requires a composite index on uid ASCENDING, timestamp DESCENDING.',
);
console.log('Firestore index contract OK: admin security event history has its composite index.');
