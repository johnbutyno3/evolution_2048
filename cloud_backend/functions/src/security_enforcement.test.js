const assert = require('assert');
const Module = require('module');

const originalLoad = Module._load;
const riskDocuments = new Map();
const enforcementDocuments = new Map();
let lastEnforcementWrite = null;
let lastDisabledUser = null;

function documentRef(store, uid) {
  return {
    async get() {
      return {
        exists: store.has(uid),
        data: () => store.get(uid) || {},
      };
    },
    async set(data) {
      store.set(uid, { ...(store.get(uid) || {}), ...data });
      lastEnforcementWrite = data;
    },
  };
}

const fakeFirestore = {
  getFirestore() {
    return {
      collection(name) {
        const store = name === 'security_risk_scores'
          ? riskDocuments
          : enforcementDocuments;
        return {
          doc(uid) {
            return documentRef(store, uid);
          },
        };
      },
    };
  },
  FieldValue: {
    serverTimestamp() {
      return 'SERVER_TIMESTAMP';
    },
  },
};

Module._load = function patchedLoad(request, parent, isMain) {
  if (request === 'firebase-admin/firestore') return fakeFirestore;
  if (request === 'firebase-admin/app') {
    return {
      getApps: () => [{}],
      initializeApp: () => ({}),
    };
  }
  if (request === 'firebase-admin/auth') {
    return {
      getAuth: () => ({
        async updateUser(uid, data) {
          lastDisabledUser = { uid, data };
        },
      }),
    };
  }
  return originalLoad.call(this, request, parent, isMain);
};

const {
  enforceSensitiveOperation,
  applyCriticalRestriction,
} = require('./security_enforcement');

Module._load = originalLoad;

function firestoreTimestamp(milliseconds) {
  return { toMillis: () => milliseconds };
}

async function expectPermissionDenied(callback) {
  await assert.rejects(callback, (error) => {
    assert.strictEqual(error.code, 'permission-denied');
    return true;
  });
}

(async () => {
  riskDocuments.set('normal', { riskScoreTotal: 0 });
  enforcementDocuments.delete('normal');
  const normal = await enforceSensitiveOperation('normal', 'purchase_tool');
  assert.deepStrictEqual(normal, {
    allowed: true,
    riskLevel: 'NORMAL',
    status: 'active',
  });

  riskDocuments.set('warning', { riskScoreTotal: 59 });
  const warning = await enforceSensitiveOperation('warning', 'purchase');
  assert.strictEqual(warning.allowed, true);
  assert.strictEqual(warning.riskLevel, 'WARNING');

  riskDocuments.set('admin-alert', { riskScoreTotal: 99 });
  const adminAlert = await enforceSensitiveOperation('admin-alert', 'spend_gold');
  assert.strictEqual(adminAlert.allowed, true);
  assert.strictEqual(adminAlert.riskLevel, 'ADMIN_ALERT');

  // A cumulative score alone is not an account lock.
  riskDocuments.set('critical-boundary', { riskScoreTotal: 100 });
  const criticalScoreOnly = await enforceSensitiveOperation(
    'critical-boundary',
    'complete_chapter',
  );
  assert.strictEqual(criticalScoreOnly.allowed, true);
  assert.strictEqual(criticalScoreOnly.riskLevel, 'CRITICAL');

  riskDocuments.set('stored-critical', {
    riskScoreTotal: 0,
    riskLevel: 'CRITICAL',
  });
  const storedRiskOnly = await enforceSensitiveOperation(
    'stored-critical',
    'start_game_session',
  );
  assert.strictEqual(storedRiskOnly.allowed, true);

  riskDocuments.set('restricted', { riskScoreTotal: 0 });
  enforcementDocuments.set('restricted', {
    status: 'restricted',
    restrictedUntil: firestoreTimestamp(Date.now() + 60_000),
  });
  await expectPermissionDenied(() =>
    enforceSensitiveOperation('restricted', 'purchase'),
  );

  enforcementDocuments.set('expired', {
    status: 'restricted',
    restrictedUntil: firestoreTimestamp(Date.now() - 1),
  });
  riskDocuments.set('expired', { riskScoreTotal: 0 });
  const expired = await enforceSensitiveOperation('expired', 'purchase');
  assert.strictEqual(expired.allowed, true);

  enforcementDocuments.set('locked', { status: 'locked' });
  riskDocuments.set('locked', { riskScoreTotal: 0 });
  await expectPermissionDenied(() =>
    enforceSensitiveOperation('locked', 'spend_gold'),
  );

  await assert.rejects(
    () => enforceSensitiveOperation('normal', 'invalid_operation'),
    (error) => error.code === 'invalid-argument',
  );

  lastEnforcementWrite = null;
  lastDisabledUser = null;
  const restriction = await applyCriticalRestriction(
    'restriction-write',
    'transaction_reuse_detected',
  );
  assert.deepStrictEqual(restriction, { status: 'locked' });
  assert.strictEqual(lastDisabledUser, null,
    'A restricted player must retain Firebase Authentication for support appeals.');
  assert.ok(lastEnforcementWrite);
  assert.strictEqual(lastEnforcementWrite.status, 'locked');
  assert.strictEqual(lastEnforcementWrite.reason, 'transaction_reuse_detected');
  assert.strictEqual(lastEnforcementWrite.updatedAt, 'SERVER_TIMESTAMP');

  await assert.rejects(
    () => applyCriticalRestriction('', 'invalid'),
    /valid uid/,
  );

  console.log('Security enforcement boundary tests passed.');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
