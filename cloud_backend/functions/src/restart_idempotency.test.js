'use strict';

const assert = require('node:assert/strict');
const {
  createRestartOperationContext,
  restartFingerprintMatches,
} = require('./restart_idempotency');

const base = {
  uid: 'test-user',
  operationId: 'restart_test_20261020',
  chapterIndex: 0,
  initialTiles: [2, null, null, null, null, null, null, null,
    null, null, null, null, null, null, null, 2],
  replaySessionId: null,
  replayLog: null,
};

const first = createRestartOperationContext(base);
const retry = createRestartOperationContext(base);
assert.deepEqual(retry, first, 'Same operation input must derive stable IDs.');
assert.equal(first.sessionId.length, 32);
assert.match(first.operationDocId, /^[a-f0-9]{64}$/);
assert.equal(
  restartFingerprintMatches({ requestFingerprint: first.requestFingerprint },
    first.requestFingerprint),
  true,
);
assert.equal(
  restartFingerprintMatches({ requestFingerprint: 'different' },
    first.requestFingerprint),
  false,
);
assert.throws(
  () => createRestartOperationContext({ ...base, operationId: 'short' }),
  (error) => error.code === 'invalid-argument',
);
assert.notEqual(
  createRestartOperationContext({ ...base, initialTiles: [4, ...base.initialTiles.slice(1)] })
    .requestFingerprint,
  first.requestFingerprint,
  'Changed payload must change the fingerprint.',
);

console.log('Restart idempotency helper tests passed.');
