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
  /exports\.refundLife\s*=\s*onCall\s*\(/,
  'Life refunds must only occur in a server-authorized transactional game flow.',
);
console.log('Life refund safety contract OK: no public refundLife callable.');

assert.doesNotMatch(
  lifeSource,
  /exports\.consumeLife\s*=\s*onCall\s*\(/,
  'Life consumption must be atomic with authorized game-session creation or restart.',
);
assert.doesNotMatch(
  fs.readFileSync(path.join(repoRoot, 'lib/game/services/life_manager.dart'), 'utf8'),
  /httpsCallable\s*\(\s*['"]consumeLife['"]\s*\)/,
  'Flutter must not use a second life-consumption path outside game sessions.',
);
console.log('Life consumption safety contract OK: no standalone consumeLife callable.');

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
  /request\.data\??\.verified|request\.data\??\.isVerified|verified\s*===\s*true/,
  'Client-provided verification flags must never be treated as trusted store verification.',
);
assert.doesNotMatch(
  purchaseCallable,
  /grantGoldToUser\s*\(|membershipRef\([^)]*\)\.set\s*\(/,
  'Purchase submission must not directly grant currency or membership.',
);
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
assert.match(
  purchaseCallable,
  /provider,\s*transactionId,\s*productId:\s*purchase\.productId,\s*createdAt:\s*FieldValue\.serverTimestamp\(\)/,
  'Transaction reservation must persist provider and exact transaction ID for replay checks.',
);
assert.match(
  purchaseCallable,
  /status:\s*'pending'/,
  'Unverified purchases must remain pending and cannot be treated as granted.',
);
assert.match(
  purchaseCallable,
  /purchase\.transactionId !== transactionId/,
  'A purchase intent cannot be rebound to another store transaction.',
);
assert.match(
  purchaseCallable,
  /purchase\.provider !== provider/,
  'A purchase intent cannot be rebound to another store provider.',
);
assert.match(
  purchaseCallable,
  /existing\.provider !== provider/,
  'A reserved transaction cannot be replayed under a different store provider.',
);
assert.match(
  purchaseCallable,
  /existing\.transactionId !== transactionId/,
  'A reserved transaction must match the exact submitted transaction ID.',
);

assert.ok(
  purchaseCallable.indexOf('const transactionSnapshot = await transaction.get(transactionRef);') <
    purchaseCallable.indexOf("if (purchase.status !== 'pending')"),
  'A terminal purchase status must not bypass global transaction replay checks.',
);
assert.match(
  purchaseCallable,
  /terminal_purchase_without_reservation/,
  'A terminal purchase without its original reservation must fail closed.',
);
assert.match(
  purchaseCallable,
  /purchase\.transactionId !== transactionId \|\|\s*purchase\.provider !== provider/,
  'An existing reservation must agree with the purchase record before returning its status.',
);

assert.match(
  purchaseCallable,
  /existing\.productId !== purchase\.productId/,
  'A reserved transaction must remain bound to the product originally associated with its purchase intent.',
);
assert.match(
  purchaseCallable,
  /productId: purchase\.productId/,
  'Transaction reservations must persist the expected product ID for trusted provider verification.',
);
assert.match(
  purchaseCallable,
  /typeof purchase\.productId !== 'string' \|\| purchase\.productId\.length === 0/,
  'Purchase verification must fail closed when the intent has no valid product binding.',
);

assert.match(
  purchaseCallable,
  /purchaseId\.trim\(\)\.length === 0 \|\| purchaseId\.length > 128/,
  'Purchase intent IDs must reject blank and oversized values before Firestore path construction.',
);
assert.match(
  purchaseCallable,
  /transactionId\.trim\(\)\.length === 0 \|\| transactionId\.length > 512/,
  'Purchase transaction IDs must reject whitespace-only and oversized input.',
);
assert.match(
  purchaseCallable,
  /typeof transactionId !== 'string' \|\| transactionId\.length === 0/,
  'Purchase transaction IDs must be non-empty strings before reservation.',
);
assert.doesNotMatch(
  purchaseCallable,
  /transactionId\.trim\(\)/,
  'Store transaction identifiers must not be silently normalized before ownership/replay binding.',
);

const purchaseTransactionStart = purchaseCallable.indexOf(
  'const outcome = await db.runTransaction',
);
const purchaseTransactionEnd = purchaseCallable.indexOf('\n  });', purchaseTransactionStart);
assert.ok(
  purchaseTransactionStart >= 0 && purchaseTransactionEnd > purchaseTransactionStart,
  'Purchase reservation must use an explicit Firestore transaction.',
);
assert.doesNotMatch(
  purchaseCallable.slice(purchaseTransactionStart, purchaseTransactionEnd),
  /recordSecurityEvent\s*\(/,
  'Firestore transaction callbacks must not perform external audit writes because callbacks can be retried.',
);
assert.match(
  purchaseCallable.slice(purchaseTransactionEnd),
  /if \(outcome\.error === 'transaction_reuse_detected'\)[\s\S]*?recordSecurityEvent\s*\(/,
  'Transaction-reuse security events must be recorded after the transaction callback finishes.',
);

console.log('Purchase verification safety contract OK: client submission remains pending only.');

// Guard the core server idempotency invariants against accidental removal.
const goldBalanceStart = indexSource.indexOf('exports.getGoldBalance = onCall(');
const goldBalanceEnd = indexSource.indexOf('\nexports.spendGold = onCall(', goldBalanceStart);
assert.ok(goldBalanceStart >= 0 && goldBalanceEnd > goldBalanceStart);
const goldBalanceCallable = indexSource.slice(goldBalanceStart, goldBalanceEnd);
const goldBalanceTransactionStart = goldBalanceCallable.indexOf(
  'const outcome = await db.runTransaction',
);
const goldBalanceTransactionEnd = goldBalanceCallable.indexOf(
  '\n  });',
  goldBalanceTransactionStart,
);
assert.ok(
  goldBalanceTransactionStart >= 0 &&
    goldBalanceTransactionEnd > goldBalanceTransactionStart,
  'Gold balance reads must validate wallet data in a Firestore transaction.',
);
assert.doesNotMatch(
  goldBalanceCallable.slice(goldBalanceTransactionStart, goldBalanceTransactionEnd),
  /recordSecurityEvent\s*\(/,
  'Gold balance transaction callbacks must not write external audit records.',
);
assert.match(
  goldBalanceCallable.slice(goldBalanceTransactionEnd),
  /outcome\.error === 'invalid_wallet_state'[\s\S]*?recordSecurityEvent\s*\(/,
  'Invalid wallet state must be audited after the transaction finishes.',
);

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

const saveManagerSource = fs.readFileSync(
  path.join(repoRoot, 'lib/game/services/save_manager.dart'),
  'utf8',
);
const clearStart = saveManagerSource.indexOf('static Future<void> clear() async {');
const clearEnd = saveManagerSource.indexOf('\n  static Map<String, dynamic>? _decode', clearStart);
assert.ok(clearStart >= 0 && clearEnd > clearStart);
const clearMethod = saveManagerSource.slice(clearStart, clearEnd);
assert.match(
  clearMethod,
  /_saveQueue = _saveQueue\.then\([\s\S]*?_clearNow\(ownerUid\)/,
  'SaveManager.clear must be serialized behind pending autosaves.',
);
assert.match(
  clearMethod,
  /static Future<void> _clearNow\(String\? ownerUid\) async \{[\s\S]*?_accountUid != ownerUid[\s\S]*?_cachedSave = null;[\s\S]*?remove\(_saveKeyFor\(ownerUid\)\)/,
  'The cache must only be cleared when the serialized clear operation executes.',
);
console.log('SaveManager clear contract OK: queued autosaves cannot overtake a clear.');


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
assert.ok(
  progressSource.includes("replaySessionId ?? 'no-session'"),
  'RESET retries must derive the same client operation key when the session ID is absent.',
);
const gamePageSource = fs.readFileSync(
  path.join(repoRoot, 'lib/game/screens/evolution_2048_page.dart'),
  'utf8',
);
assert.ok(
  gamePageSource.includes("replaySessionId ?? 'no-session'"),
  'RESET completion must clear the same operation key used by the request.',
);
const pendingStoreSource = fs.readFileSync(
  path.join(repoRoot, 'lib/game/services/pending_operation_store.dart'),
  'utf8',
);
assert.match(pendingStoreSource, /savePendingPayload/);
assert.match(pendingStoreSource, /findPendingPayload/);
assert.match(pendingStoreSource, /restoreOperationId/);
assert.match(pendingStoreSource, /_payloadStorageKey/);
assert.ok(
  pendingStoreSource.includes('Account changed while waiting for the pending operation lock.'),
  'A queued operation must abort if auth changes before its action begins.',
);
assert.ok(
  pendingStoreSource.includes('Account changed while loading the operation ID.'),
  'Operation IDs must not be read or created after an account switch during storage initialization.',
);
assert.ok(
  pendingStoreSource.includes('Account changed while saving the operation ID.'),
  'An operation ID write must remain tied to the UID captured before asynchronous storage access.',
);
assert.ok(
  pendingStoreSource.includes('Account changed before the pending payload could be stored.'),
  'A pending payload must never combine one account key with another account operation ID.',
);
assert.ok(
  pendingStoreSource.includes('if (_uid != uid) return null;'),
  'Pending payload discovery must abort if the signed-in UID changes during storage access.',
);
const completeStart = pendingStoreSource.indexOf('static Future<void> complete(');
assert.notEqual(completeStart, -1);
const completeSource = pendingStoreSource.slice(completeStart);
assert.ok(
  completeSource.indexOf('remove(_storageKey(') <
    completeSource.indexOf('remove(_payloadStorageKey('),
  'Completion must remove the idempotency key before the recovery payload so a crash cannot leave a reusable orphan key.',
);
assert.ok(
  completeSource.includes('if (_uid != uid) {') &&
    completeSource.indexOf('if (_uid != uid) {') <
      completeSource.indexOf('remove(_storageKey('),
  'Pending completion must verify the captured UID before removing either recovery key.',
);
assert.match(
  gamePageSource,
  /final payload = await PendingOperationStore\.findPendingPayload\([\s\S]*?if \(!mounted \|\| generation != _gameSessionGeneration \|\| !_ownsCurrentAccount\) \{\s*return false;\s*\}\s*if \(payload == null\) return null;/s,
  'A RESET lookup interrupted by account switching must not be mistaken for no pending operation.',
);
assert.match(
  gamePageSource,
  /Future<void> _handleSystemBack\(\)[\s\S]*?final unresolvedReset = await PendingOperationStore\.findPendingPayload\([\s\S]*?if \(!mounted \|\| !_ownsCurrentAccount\) \{\s*_handlingSystemBack = false;\s*return;\s*\}/s,
  'System-back must stop if auth changes while checking unresolved RESET state.',
);
assert.match(
  pendingStoreSource,
  /Pending operation payload is corrupted/,
  'Corrupt pending RESET data must block new session creation rather than be ignored.',
);
assert.match(
  pendingStoreSource,
  /Pending operation payload is not a JSON object/,
  'A non-object pending record must fail closed.',
);
assert.match(
  gamePageSource,
  /_recoverPendingReset/,
  'Startup must attempt recovery before routing to a new game session.',
);
assert.match(
  gamePageSource,
  /'replacementSave': newEngine\.createSaveData\(\)/,
  'RESET recovery must persist the exact replacement board snapshot before the callable.',
);
assert.match(
  gamePageSource,
  /PendingOperationStore\.complete\([\s\S]*?resetOperationKey/s,
  'RESET recovery data must be cleared only after the replacement snapshot is saved.',
);
const resetPayloadWriteIndex = gamePageSource.indexOf(
  'await PendingOperationStore.savePendingPayload(',
);
const resetCallableIndex = gamePageSource.indexOf(
  'final restartFuture = PlayerProgressService.instance.restartGameSession(',
);
assert.ok(
  resetPayloadWriteIndex >= 0 &&
    resetCallableIndex > resetPayloadWriteIndex,
  'The full RESET request and board snapshot must be persisted before the backend call.',
);
const resetEngineSwapIndex = gamePageSource.indexOf(
  '      _engine = newEngine;',
  resetPayloadWriteIndex,
);
assert.ok(
  resetEngineSwapIndex > resetPayloadWriteIndex &&
    resetEngineSwapIndex < resetCallableIndex,
  'The replacement board must not become active before its recovery payload is durable.',
);
assert.match(
  gamePageSource,
  /RESET blocked: an earlier reset still needs recovery/,
  'A second RESET must not replace an unresolved operation payload.',
);
assert.match(
  progressSource,
  /_loadedFromServer && refreshedSessionId == previousSessionId/,
  'A pending RESET may only be discarded after an authoritative refresh confirms no commit.',
);
assert.match(
  progressSource,
  /PendingOperationStore\.complete\([\s\S]*?operationKey/s,
  'Confirmed non-committed RESET operations must clear their pending payload.',
);
assert.match(
  gamePageSource,
  /findPendingPayload\(\s*'restart_game_session',\s*\)/,
  'Startup must detect an unresolved RESET even if the player opens another chapter.',
);
const resetAmbiguousIndex = gamePageSource.indexOf(
  'final unresolvedReset = await PendingOperationStore.findPendingPayload(',
);
const resetRollbackIndex = gamePageSource.indexOf(
  'await SaveManager.save(oldEngine.createSaveData());',
  resetAmbiguousIndex,
);
assert.ok(
  resetAmbiguousIndex >= 0 && resetRollbackIndex > resetAmbiguousIndex,
  'RESET must check for an unresolved operation before restoring the old board after a false result.',
);
assert.match(
  gamePageSource,
  /void _move\(String direction\) \{[\s\S]*?if \(_restartInProgress \|\|/,
  'The core movement function must independently enforce the RESET interaction lock.',
);
assert.match(
  gamePageSource,
  /void _resumeGameplay\(\) \{[\s\S]*?if \(_restartInProgress\) \{[\s\S]*?_engine\.pauseGameTimer\(\)/,
  'Resuming the app must not restart the gameplay timer while RESET is unresolved.',
);
assert.match(
  gamePageSource,
  /if \(_restartInProgress\) return; final mode = _toolMode/,
  'Gameplay tools must remain disabled while an ambiguous RESET is awaiting recovery.',
);
const backHandlerStart = gamePageSource.indexOf('Future<void> _handleSystemBack()');
const backHandlerEnd = gamePageSource.indexOf('Future<void> _showResetMenu()', backHandlerStart);
assert.ok(backHandlerStart >= 0 && backHandlerEnd > backHandlerStart);
const backHandler = gamePageSource.slice(backHandlerStart, backHandlerEnd);
const unresolvedBackCheck = backHandler.search(
  /PendingOperationStore\.findPendingPayload\(\s*'restart_game_session',/,
);
const abandonOnBack = backHandler.indexOf('abandonGameSession(');
assert.ok(
  unresolvedBackCheck >= 0 && abandonOnBack > unresolvedBackCheck,
  'Back navigation must check for unresolved RESET before any session abandon or save.',
);
assert.match(
  backHandler,
  /if \(unresolvedReset != null\) \{[\s\S]*?Navigator\.of\(context\)\.pop\(\);[\s\S]*?return;/,
  'Leaving with an unresolved RESET must pop without running normal session settlement.',
);
console.log('RESET crash recovery contract OK: payload, operation ID, and board snapshot are persisted and replayed.');

const nextChapterStart = gamePageSource.indexOf(
  'Future<void> _startChapter(GameChapter chapter',
);
const nextChapterEnd = gamePageSource.indexOf('\n  @override\n  Widget build', nextChapterStart);
assert.ok(nextChapterStart >= 0 && nextChapterEnd > nextChapterStart);
const nextChapterSource = gamePageSource.slice(nextChapterStart, nextChapterEnd);
const nextChapterPayloadIndex = nextChapterSource.indexOf(
  "await PendingOperationStore.savePendingPayload(",
);
const nextChapterCallableIndex = nextChapterSource.indexOf(
  "PlayerProgressService.instance.restartGameSession(",
);
assert.ok(
  nextChapterPayloadIndex >= 0 && nextChapterCallableIndex > nextChapterPayloadIndex,
  'Next-chapter transition must persist its operation ID and replacement board before the callable.',
);
assert.match(
  nextChapterSource,
  /'replacementSave': newEngine\.createSaveData\(\)/,
  'Next-chapter recovery must retain the exact replacement board.',
);
assert.match(
  nextChapterSource,
  /if \(unresolved != null\) \{[\s\S]*?_restartInProgress = true/,
  'An ambiguous next-chapter transition must freeze rather than roll back the visible board.',
);
assert.match(
  nextChapterSource,
  /await PendingOperationStore\.complete\(\s*'restart_game_session',\s*operationKey,\s*expectedUid:\s*_accountUidAtCreation/s,
  'A confirmed next-chapter transition must clear its pending recovery payload after saving.',
);
console.log('Next-chapter transition contract OK: durable idempotency payload precedes the backend request.');




const mainSource = fs.readFileSync(path.join(repoRoot, 'lib/main.dart'), 'utf8');
const loginSource = fs.readFileSync(
  path.join(repoRoot, 'lib/screens/login_register_page.dart'),
  'utf8',
);
const logoutSource = fs.readFileSync(
  path.join(repoRoot, 'lib/screens/personal_page.dart'),
  'utf8',
);
assert.match(
  progressSource,
  /Future<void> bindAccount\(String\? uid\)[\s\S]*?_sessionOperationGeneration\+\+[\s\S]*?_chapterProgress\.clear\(\)[\s\S]*?_activeGameSessionId = null/s,
  'Account binding must invalidate in-flight operations and clear singleton progression state.',
);
assert.match(
  mainSource,
  /Future<void> _bindAccountData\(String\? uid\)[\s\S]*?SaveManager\.bindAccount\(uid\)[\s\S]*?PlayerProgressService\.instance\.bindAccount\(uid\)/s,
  'The root Auth router must bind local saves and singleton progress together.',
);
assert.match(
  mainSource,
  /future: _bindAccountData\(null\)/,
  'Auth-state sign-out must clear the bound account even when logout happens outside the Personal page.',
);
assert.match(
  loginSource,
  /SaveManager\.bindAccount\(user\.uid\)[\s\S]*?PlayerProgressService\.instance\.bindAccount\(user\.uid\)/s,
  'Post-login navigation must bind progression state to the same UID as local saves.',
);
assert.match(
  logoutSource,
  /SaveManager\.bindAccount\(null\)[\s\S]*?PlayerProgressService\.instance\.bindAccount\(null\)/s,
  'Logout must clear the singleton progression state as well as the save namespace.',
);
console.log('Account binding contract OK: UID changes invalidate singleton progress and session state.');


assert.match(
  saveManagerSource,
  /getString\(key\) == sessionIdToClear/,
  'Queued cleanup must not erase a session ID that has already been replaced.',
);
assert.match(
  gamePageSource,
  /bool get _ownsCurrentAccount[\s\S]*?FirebaseAuth\.instance\.currentUser\?\.uid == _accountUidAtCreation[\s\S]*?SaveManager\.accountUid == _accountUidAtCreation/s,
  'Game-page asynchronous actions must verify both Firebase UID and SaveManager ownership.',
);
const restartMethodStart = progressSource.indexOf('Future<bool> restartGameSession(');
const abandonMethodStart = progressSource.indexOf('Future<void> abandonGameSession(', restartMethodStart);
assert.ok(restartMethodStart >= 0 && abandonMethodStart > restartMethodStart);
const restartMethodSource = progressSource.slice(restartMethodStart, abandonMethodStart);
assert.match(
  restartMethodSource,
  /getOrCreate\([\s\S]*?operationGeneration != _sessionOperationGeneration[\s\S]*?_auth\.currentUser\?\.uid != user\.uid[\s\S]*?restartGameSession/s,
  'Restart must recheck UID/generation after awaiting its idempotency key and before the callable.',
);
assert.match(
  gamePageSource,
  /RESET completion failed:[\s\S]*?findPendingPayload\([\s\S]*?restart_game_session[\s\S]*?if \(unresolvedReset != null\)/s,
  'An ambiguous RESET exception must preserve the pending payload and fail closed instead of rolling back blindly.',
);
console.log('Account/session race contract OK: stale session cleanup and ambiguous RESET cannot cross account boundaries.');

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
