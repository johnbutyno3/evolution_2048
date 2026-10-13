const assert = require('assert');
const {
  createRestartOperationContext,
} = require('./restart_idempotency');

const base = {
  uid: 'test-user',
  operationId: 'restart_1234567890_abcd',
  chapterIndex: 0,
  initialTiles: [2, null, null, null, null, null, null, null,
    null, null, null, null, null, null, null, 2],
  replaySessionId: 'old-session',
  replayLog: { moves: 4, toolUsage: {} },
};

const first = createRestartOperationContext(base);
const retry = createRestartOperationContext({ ...base });
assert.deepStrictEqual(retry, first,
  'The same retry payload must resolve to the same operation and session.');

const changedBoard = createRestartOperationContext({
  ...base,
  initialTiles: [4, null, null, null, null, null, null, null,
    null, null, null, null, null, null, null, 2],
});
assert.notStrictEqual(changedBoard.requestFingerprint, first.requestFingerprint,
  'Different payloads must not be accepted as the same operation.');
assert.strictEqual(changedBoard.operationDocId, first.operationDocId,
  'The operation key stays the same so the server can reject changed payloads.');
assert.strictEqual(changedBoard.sessionId, first.sessionId,
  'A retry key must not create a second session ID.');

assert.throws(
  () => createRestartOperationContext({ ...base, operationId: 'short' }),
  (error) => error.code === 'invalid-argument',
);
assert.throws(
  () => createRestartOperationContext({ ...base, uid: '' }),
  /valid uid/,
);

console.log('Restart idempotency helper tests passed.');
