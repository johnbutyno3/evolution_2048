const assert = require('assert');
const {
  calculateRiskScore,
  normalizeAuditSeverity,
  recordSecurityEvent,
  riskLevel,
} = require('./security_audit');

assert.strictEqual(normalizeAuditSeverity('warning'), 'WARNING');
assert.strictEqual(normalizeAuditSeverity('suspicious'), 'SUSPICIOUS');
assert.strictEqual(normalizeAuditSeverity('confirmed'), 'CONFIRMED');
assert.strictEqual(normalizeAuditSeverity('high'), 'CONFIRMED');
assert.strictEqual(normalizeAuditSeverity('critical'), 'CRITICAL');
assert.strictEqual(normalizeAuditSeverity('unknown'), 'WARNING');

assert.strictEqual(calculateRiskScore('data_mismatch'), 10);
assert.strictEqual(calculateRiskScore('abnormal_frequency'), 20);
assert.strictEqual(calculateRiskScore('illegal_tool_quantity'), 50);
assert.strictEqual(calculateRiskScore('tool_inventory_invalid_or_empty'), 50);
assert.strictEqual(calculateRiskScore('tool_not_allowed_for_chapter'), 50);
assert.strictEqual(calculateRiskScore('illegal_gold'), 80);
assert.strictEqual(calculateRiskScore('transaction_reuse_detected'), 100);
assert.strictEqual(calculateRiskScore('forged_receipt'), 100);
assert.strictEqual(riskLevel(0), 'NORMAL');
assert.strictEqual(riskLevel(30), 'WARNING');
assert.strictEqual(riskLevel(60), 'ADMIN_ALERT');
assert.strictEqual(riskLevel(100), 'CRITICAL');

let written;
let riskWritten;
const db = {
  collection(name) {
    assert.ok(name === 'security_events' || name === 'security_risk_scores');
    return {
      doc() {
        if (name === 'security_events') {
          return {
            id: 'test-event-id',
            set(data) {
              written = data;
              return Promise.resolve();
            },
          };
        }

        return {
          set(data) {
            riskWritten = data;
            return Promise.resolve();
          },
        };
      },
    };
  },
};

recordSecurityEvent(db, {
  uid: 'uid-1',
  action: 'test_event',
  severity: 'high',
  reason: 'illegal_gold',
  details: {
    toolType: 'timeRewind',
    requestId: 'request-1',
    platform: 'android',
    appVersion: '1.0.0',
    clientValue: 100,
    serverValue: 0,
    productId: 'gold_pack_1',
    transactionId: 'transaction-1',
  },
  status: 'rejected',
}).then(() => {
  assert.strictEqual(written.eventId, 'test-event-id');
  assert.strictEqual(written.uid, 'uid-1');
  assert.strictEqual(written.eventType, 'test_event');
  assert.strictEqual(written.severity, 'CONFIRMED');
  assert.strictEqual(written.reason, 'illegal_gold');
  assert.strictEqual(written.clientValue, 100);
  assert.strictEqual(written.serverValue, 0);
  assert.strictEqual(written.productId, 'gold_pack_1');
  assert.strictEqual(written.toolType, 'timeRewind');
  assert.strictEqual(written.transactionId, 'transaction-1');
  assert.strictEqual(written.requestId, 'request-1');
  assert.strictEqual(written.platform, 'android');
  assert.strictEqual(written.appVersion, '1.0.0');
  assert.strictEqual(written.status, 'rejected');
  assert.strictEqual(written.riskScore, 80);
  assert.strictEqual(written.riskLevel, 'ADMIN_ALERT');
  assert.strictEqual(written.auditSchemaVersion, 2);
  assert.strictEqual(riskWritten.uid, 'uid-1');
  assert.ok(riskWritten.riskScoreTotal);
  assert.strictEqual(riskWritten.lastEventScore, 80);
  assert.strictEqual(riskWritten.lastEventRiskLevel, 'ADMIN_ALERT');
  assert.strictEqual(riskWritten.lastEventId, 'test-event-id');
  assert.strictEqual(riskWritten.riskSchemaVersion, 1);
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
