'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const start = source.indexOf('exports.submitPurchaseForVerification = onCall(');
const end = source.indexOf('\nasync function consumeLifeInTransaction', start);

assert.notEqual(start, -1, 'Purchase verification callable must exist.');
assert.ok(end > start, 'Purchase verification callable boundary must exist.');

const callable = source.slice(start, end);

// Client-supplied transaction IDs are not proof of payment. This endpoint
// must remain pending-only until trusted Apple/Google verification is added.
assert.match(callable, /status:\s*'pending'/);
assert.doesNotMatch(
  callable,
  /grantGoldToUser\s*\(|membershipRef\([^)]*\)\.set\s*\(/,
  'Unverified client transaction IDs must never grant Gold or membership.',
);

// A pending purchase intent cannot be rebound to another transaction/provider.
assert.match(
  callable,
  /purchase\.transactionId\s*&&\s*purchase\.transactionId\s*!==\s*transactionId/,
  'A purchase intent must reject a different transaction ID once bound.',
);
assert.match(
  callable,
  /purchase\.provider\s*!==\s*'pending'\s*&&\s*purchase\.provider\s*!==\s*provider/,
  'A purchase intent must reject a different provider once bound.',
);
assert.match(
  callable,
  /existing\.provider\s*!==\s*provider/,
  'A transaction reservation cannot be reused under a different provider.',
);

console.log('Purchase safety contract passed: pending-only and purchase intent binding enforced.');
