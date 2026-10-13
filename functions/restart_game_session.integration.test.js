const assert = require('assert');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const {
  createRestartOperationContext,
} = require('./restart_idempotency');

// This test must run with FIRESTORE_EMULATOR_HOST set by firebase emulators:exec.
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('FIRESTORE_EMULATOR_HOST is required; refusing to run against production.');
}
if (getApps().length === 0) {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-rebirth-2048' });
}
const db = getFirestore();

async function main() {
  const uid = 'restart-idempotency-integration-user';
  const operationId = 'restart_integration_20261013_001';
  const userRef = db.collection('users').doc(uid);
  const progressRef = userRef.collection('progress').doc('game');
  const lifeRef = userRef.collection('life').doc('current');
  const membershipRef = userRef.collection('membership').doc('current');
  const board = [2, null, null, null, null, null, null, null,
    null, null, null, null, null, null, null, 2];
  const requestData = {
    operationId,
    chapterIndex: 0,
    initialTiles: board,
  };
  const operationContext = createRestartOperationContext({
    uid,
    operationId,
    chapterIndex: 0,
    initialTiles: board,
    replaySessionId: null,
    replayLog: null,
  });
  const operationRef = userRef.collection('game_session_operations')
    .doc(operationContext.operationDocId);
  const sessionsRef = userRef.collection('game_sessions');

  try {
    await userRef.delete().catch(() => {});
    await progressRef.set({ unlockedChapterIndex: 0 });
    await lifeRef.set({ lives: 5, regenStartAt: null });
    await membershipRef.delete().catch(() => {});

    const { restartGameSession } = require('./game_session');
    assert(restartGameSession && typeof restartGameSession.run === 'function',
      'restartGameSession must expose its callable handler for integration testing.');
    const invoke = (data) => restartGameSession.run({
      auth: { uid, token: { firebase: { sign_in_provider: 'custom' } } },
      app: { appId: 'integration-test-app' },
      data,
    });

    const [first, concurrentRetry] = await Promise.all([
      invoke(requestData),
      invoke(requestData),
    ]);
    assert.strictEqual(first.sessionId, concurrentRetry.sessionId,
      'Concurrent identical requests must return the same session.');
    assert.strictEqual(first.lives, 4);
    assert.strictEqual(concurrentRetry.lives, 4);

    const retryAfterCommit = await invoke(requestData);
    assert.deepStrictEqual(retryAfterCommit, first,
      'A retry after commit must return the original result.');

    const changedBoard = [...board];
    changedBoard[0] = 4;
    await assert.rejects(
      invoke({ ...requestData, initialTiles: changedBoard }),
      (error) => error.code === 'failed-precondition',
      'Reusing an operation ID with a different payload must be rejected.',
    );

    const [lifeSnapshot, progressSnapshot, operationSnapshot, sessionSnapshots] =
      await Promise.all([
        lifeRef.get(),
        progressRef.get(),
        operationRef.get(),
        sessionsRef.get(),
      ]);
    assert.strictEqual(lifeSnapshot.data().lives, 4,
      'Life must be deducted exactly once.');
    assert.strictEqual(progressSnapshot.data().activeGameSessionId, first.sessionId,
      'Progress must point at the replacement session.');
    assert(operationSnapshot.exists, 'The operation record must be committed.');
    assert.strictEqual(operationSnapshot.data().result.sessionId, first.sessionId);
    assert.strictEqual(sessionSnapshots.size, 1,
      'Only one replacement session may be created.');

    console.log('Firestore restart idempotency integration tests passed.');
  } finally {
    await db.recursiveDelete(userRef);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
