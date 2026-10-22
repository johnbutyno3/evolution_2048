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
const expiryStart = source.indexOf(
  'exports.simulateGoldenExpiryForDevelopment = onCall(',
  cancellationStart,
);
const refundStart = source.indexOf(
  'exports.simulateRefundForDevelopment = onCall(',
  expiryStart,
);
const verifierStart = source.indexOf(
  'exports.submitPurchaseForVerification = onCall(',
  refundStart,
);
const cancellation = source.slice(cancellationStart, expiryStart);
assert.ok(expiryStart > cancellationStart);
const expiry = source.slice(expiryStart, refundStart);
const refund = source.slice(refundStart, verifierStart);
assert.match(expiry, /FUNCTIONS_EMULATOR !== 'true'/);
assert.match(expiry, /!process\.env\.FIRESTORE_EMULATOR_HOST/);
assert.match(expiry, /ENABLE_PURCHASE_SIMULATOR !== 'true'/);
assert.match(expiry, /purchase\.simulated !== true/);
assert.match(expiry, /purchase\.membershipType !== 'golden'/);
assert.match(expiry, /expiryMillis > now/);
assert.match(expiry, /membership\.premiumLifetime === true/);
assert.match(expiry, /type: fallbackToPremium \? 'premium' : 'general'/);
assert.match(expiry, /status: 'simulated_expired'/);
assert.doesNotMatch(expiry, /premiumLifetime: false/);
assert.match(cancellation, /FUNCTIONS_EMULATOR !== 'true'/);
assert.match(cancellation, /!process\.env\.FIRESTORE_EMULATOR_HOST/);
assert.match(cancellation, /ENABLE_PURCHASE_SIMULATOR !== 'true'/);
assert.match(cancellation, /purchase\.simulated !== true/);
assert.match(cancellation, /purchase\.membershipType !== 'golden'/);
assert.match(cancellation, /goldenSourcePurchaseId \\|\\| membership\.sourcePurchaseId/);
assert.match(cancellation, /autoRenew: false/);
assert.match(cancellation, /cancellationEffectiveAt: expiresAt/);
assert.match(cancellation, /benefitsRemainUntilExpiry: true/);
assert.doesNotMatch(cancellation, /goldenActive: false|premiumLifetime: false/);

assert.ok(simulatorStart >= 0 && refundStart > expiryStart && verifierStart > refundStart);

const simulator = source.slice(simulatorStart, cancellationStart);
assert.match(simulator, /FUNCTIONS_EMULATOR !== 'true'/);
assert.match(simulator, /!process\.env\.FIRESTORE_EMULATOR_HOST/);
assert.match(simulator, /ENABLE_PURCHASE_SIMULATOR !== 'true'/);
assert.match(simulator, /simulated: true/);
assert.match(simulator, /priceUsd: product\.priceUsd/);
assert.match(simulator, /productType: product\.type/);
assert.match(simulator, /membershipType: product\.membershipType/);
assert.match(simulator, /goldGranted: isGrantScenario/);
assert.match(simulator, /goldenSourcePurchaseId: isGolden/);
assert.match(simulator, /premiumSourcePurchaseId: isGolden/);
assert.match(simulator, /simulatedGoldenCycleGold/);
assert.match(simulator, /transactionSnapshot\.exists/);
assert.match(simulator, /existing\.provider !== 'simulator'/);
assert.doesNotMatch(
  simulator,
  /exports\.submitPurchaseForVerification|request\.data\??\.verified/,
);

assert.match(refund, /FUNCTIONS_EMULATOR !== 'true'/);
assert.match(refund, /!process\.env\.FIRESTORE_EMULATOR_HOST/);
assert.match(refund, /ENABLE_PURCHASE_SIMULATOR !== 'true'/);
assert.match(refund, /purchase\.simulated !== true/);
assert.match(refund, /purchase\.simulated !== true/);
assert.match(refund, /reservation\.purchaseId !== purchaseId/);
assert.match(refund, /Math\.min\(balance, purchase\.goldGranted\)/);
assert.match(refund, /goldUnrecovered = purchase\.goldGranted - goldRevoked/);
assert.match(refund, /status: 'simulated_refunded'/);
assert.match(refund, /premiumSourcePurchaseId !== purchaseId/);
assert.match(refund, /goldenSourcePurchaseId \|\| membership\.sourcePurchaseId/);
assert.doesNotMatch(refund, /balance: balance - purchase\.goldGranted/);

const verifier = source.slice(verifierStart);
assert.match(verifier, /PURCHASE_PROVIDERS\.has\(provider\)/);
assert.match(verifier, /purchase\.status !== 'pending'/);
assert.match(verifier, /transactionReuseDetected|transaction_reuse_detected/);
assert.match(verifier, /terminal_purchase_without_reservation/);

console.log('Purchase safety contract OK: emulator-only simulation and transaction-bound verification.');
