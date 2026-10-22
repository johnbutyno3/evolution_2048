'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');

const intentStart = source.indexOf('exports.createPurchaseIntent = onCall(');
const simulatorStartForIntent = source.indexOf(
  'exports.simulatePurchaseForDevelopment = onCall(',
  intentStart,
);
assert.ok(intentStart >= 0 && simulatorStartForIntent > intentStart);
const purchaseIntent = source.slice(intentStart, simulatorStartForIntent);
assert.match(purchaseIntent, /priceUsd: product\.priceUsd/);
assert.match(purchaseIntent, /productType: product\.type/);
assert.match(purchaseIntent, /membershipType: product\.membershipType/);

const simulatorStart = source.indexOf(
  'exports.simulatePurchaseForDevelopment = onCall(',
);
const cancellationStart = source.indexOf(
  'exports.simulateGoldenCancellationForDevelopment = onCall(',
  simulatorStart,
);
assert.ok(cancellationStart > simulatorStart);
const cancellation = source.slice(cancellationStart, verifierStart);
assert.match(cancellation, /FUNCTIONS_EMULATOR !== 'true'/);
assert.match(cancellation, /!process\.env\.FIRESTORE_EMULATOR_HOST/);
assert.match(cancellation, /ENABLE_PURCHASE_SIMULATOR !== 'true'/);
assert.match(cancellation, /purchase\.simulated !== true/);
assert.match(cancellation, /purchase\.membershipType !== 'golden'/);
assert.match(cancellation, /membership\.sourcePurchaseId !== purchaseId/);
assert.match(cancellation, /autoRenew: false/);
assert.match(cancellation, /cancellationEffectiveAt: expiresAt/);
assert.match(cancellation, /benefitsRemainUntilExpiry: true/);
assert.doesNotMatch(cancellation, /goldenActive: false|premiumLifetime: false/);

const verifierStart = source.indexOf(
  'exports.submitPurchaseForVerification = onCall(',
  simulatorStart,
);
assert.ok(simulatorStart >= 0 && verifierStart > simulatorStart);

const simulator = source.slice(simulatorStart, verifierStart);
assert.match(simulator, /FUNCTIONS_EMULATOR !== 'true'/);
assert.match(simulator, /!process\.env\.FIRESTORE_EMULATOR_HOST/);
assert.match(simulator, /ENABLE_PURCHASE_SIMULATOR !== 'true'/);
assert.match(simulator, /simulated: true/);
assert.match(simulator, /priceUsd: product\.priceUsd/);
assert.match(simulator, /productType: product\.type/);
assert.match(simulator, /membershipType: product\.membershipType/);
assert.match(simulator, /goldGranted: isGrantScenario/);
assert.match(simulator, /simulatedGoldenCycleGold/);
assert.match(simulator, /transactionSnapshot\.exists/);
assert.match(simulator, /existing\.provider !== 'simulator'/);
assert.doesNotMatch(
  simulator,
  /exports\.submitPurchaseForVerification|request\.data\??\.verified/,
);

const verifier = source.slice(verifierStart);
assert.match(verifier, /PURCHASE_PROVIDERS\.has\(provider\)/);
assert.match(verifier, /purchase\.status !== 'pending'/);
assert.match(verifier, /transactionReuseDetected|transaction_reuse_detected/);
assert.match(verifier, /terminal_purchase_without_reservation/);

console.log('Purchase safety contract OK: emulator-only simulation and transaction-bound verification.');
