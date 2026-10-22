'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const simulatorStart = source.indexOf(
  'exports.simulatePurchaseForDevelopment = onCall(',
);
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
