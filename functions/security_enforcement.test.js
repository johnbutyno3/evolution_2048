const assert = require('assert');
const Module = require('module');

const originalLoad = Module._load;
const riskDocuments = new Map();
const enforcementDocuments = new Map();
let lastEnforcementWrite = null;

function documentRef(store, uid) {
  return {
    async get() {
      return {
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
  if (request === 'firebase-admin/firestore') {
    return fakeFirestore;
  }
  return originalLoad.call(this, request, parent, isMain);
};

const {
  enforceSensitiveOperation,
  applyCriticalRestriction,
} = require('./security_enforcement');

Module._load = originalLoad;

function firestoreTimestamp(milliseconds) {
  return {
    toMillis: () => milliseconds,
  };
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
  const normal = await enforceSensitiveOperation('normal', 'use_tool');
  assert.deepStrictEqual(normal, {
    allowed: true,
    riskLevel: 'NORMAL',
    status: 'active',
  });

  riskDocuments.set('warning', { riskScoreTotal: 59 });
  const warning = await enforceSensitiveOperation('warning', 'purchase_tool');
  assert.strictEqual(warning.allowed, true);
  assert.strictEqual(warning.riskLevel, 'WARNING');

  riskDocuments.set('admin-alert', { riskScoreTotal: 99 });
  const adminAlert = await enforceSensitiveOperation('admin-alert', 'spend_gold');
  assert.strictEqual(adminAlert.allowed, true);
  assert.strictEqual(adminAlert.riskLevel, 'ADMIN_ALERT');

  riskDocuments.set('critical-boundary', { riskScoreTotal: 100 });
  await expectPermissionDenied(() =>
    enforceSensitiveOperation('critical-boundary', 'complete_chapter'),
  );

  riskDocuments.set('stored-critical', {
    riskScoreTotal: 0,
    riskLevel: 'CRITICAL',
  });
  await expectPermissionDenied(() =>
    enforceSensitiveOperation('stored-critical', 'start_game_session'),
  );

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

  riskDocuments.set('high-but-not-critical', { riskScoreTotal: 80 });
  enforcementDocuments.delete('high-but-not-critical');
  const highButNotCritical = await enforceSensitiveOperation(
    'high-but-not-critical',
    'grant_membership',
  );
  assert.strictEqual(highButNotCritical.allowed, true);
  assert.strictEqual(highButNotCritical.riskLevel, 'ADMIN_ALERT');

  await assert.rejects(
    () => enforceSensitiveOperation('normal', 'invalid_operation'),
    (error) => error.code === 'invalid-argument',
  );

  const before = Date.now();
  lastEnforcementWrite = null;
  const restriction = await applyCriticalRestriction(
    'restriction-write',
    'critical_security_risk',
    31 * 24 * 60 * 60 * 1000,
  );
  const after = Date.now();
  assert.strictEqual(restriction.status, 'restricted');
  assert.ok(lastEnforcementWrite);
  assert.strictEqual(lastEnforcementWrite.status, 'restricted');
  assert.strictEqual(lastEnforcementWrite.reason, 'critical_security_risk');
  assert.ok(lastEnforcementWrite.restrictedUntil >= new Date(before + 30 * 24 * 60 * 60 * 1000));
  assert.ok(lastEnforcementWrite.restrictedUntil <= new Date(after + 30 * 24 * 60 * 60 * 1000));
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
