'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { after, before, test } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

const repoRoot = path.resolve(__dirname, '../../..');
let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-rebirth-2048-rules',
    firestore: {
      rules: fs.readFileSync(path.join(repoRoot, 'firestore.rules'), 'utf8'),
    },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), { displayName: 'Alice', isAdmin: false });
    await setDoc(doc(db, 'users/bob'), { displayName: 'Bob', isAdmin: false });
    await setDoc(doc(db, 'users/alice/progress/chapter1'), { stage: 2 });
    await setDoc(doc(db, 'users/alice/wallet/main'), { gold: 100 });
    await setDoc(doc(db, 'users/alice/membership/golden'), { active: true });
    await setDoc(doc(db, 'users/alice/purchases/purchase-1'), { status: 'pending' });
    await setDoc(doc(db, 'config/gameplay'), { enabled: true });
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test('unauthenticated clients cannot read or write user data', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users/alice')));
  await assertFails(setDoc(doc(db, 'users/alice'), { displayName: 'Forged' }));
});

test('a signed-in user can read their own profile and progress but cannot write them', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/alice')));
  await assertSucceeds(getDoc(doc(db, 'users/alice/progress/chapter1')));
  await assertFails(setDoc(doc(db, 'users/alice'), { displayName: 'Forged' }));
  await assertFails(setDoc(doc(db, 'users/alice/progress/chapter1'), { stage: 999 }));
});

test('users cannot access another account profile, progress, wallet, or membership', async () => {
  const db = testEnv.authenticatedContext('bob').firestore();
  await assertFails(getDoc(doc(db, 'users/alice')));
  await assertFails(getDoc(doc(db, 'users/alice/progress/chapter1')));
  await assertFails(getDoc(doc(db, 'users/alice/wallet/main')));
  await assertFails(getDoc(doc(db, 'users/alice/membership/golden')));
  await assertFails(getDoc(doc(db, 'users/alice/purchases/purchase-1')));
});

test('authoritative sessions, reset receipts, purchase ledger, and security records are server-only', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  const deniedPaths = [
    'users/alice/game_sessions/session-1',
    'users/alice/game_session_operations/reset-1',
    'purchase_transactions/transaction-1',
    'security_events/event-1',
    'security_risk_scores/alice',
    'security_enforcement/alice',
    'support_cases/case-1',
    'support_cases/case-1/messages/message-1',
  ];

  for (const documentPath of deniedPaths) {
    await assertFails(getDoc(doc(db, documentPath)), `read should be denied: ${documentPath}`);
    await assertFails(
      setDoc(doc(db, documentPath), { forged: true }),
      `write should be denied: ${documentPath}`,
    );
  }
});

test('users may read their own wallet, membership, and purchase status but cannot write them', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  for (const documentPath of [
    'users/alice/wallet/main',
    'users/alice/membership/golden',
    'users/alice/purchases/purchase-1',
  ]) {
    await assertSucceeds(getDoc(doc(db, documentPath)));
    await assertFails(
      setDoc(doc(db, documentPath), { forged: true }),
      `authoritative write should be denied: ${documentPath}`,
    );
  }
});

test('feedback creation is limited to the authenticated UID and is immutable to clients', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(db, 'feedback/alice-feedback'), { uid: 'alice', message: 'help' }),
  );
  await assertFails(
    setDoc(doc(db, 'feedback/forged-feedback'), { uid: 'bob', message: 'forged' }),
  );
  await assertFails(
    setDoc(doc(db, 'feedback/alice-feedback'), { uid: 'alice', message: 'changed' }),
  );
});

test('signed-in clients can read shared config but cannot mutate it', async () => {
  const db = testEnv.authenticatedContext('alice').firestore();
  await assertSucceeds(getDoc(doc(db, 'config/gameplay')));
  await assertFails(setDoc(doc(db, 'config/gameplay'), { enabled: false }));
});
