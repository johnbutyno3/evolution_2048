const assert = require('assert');
const { normalizeAuditSeverity, recordSecurityEvent } = require('./security_audit');

assert.strictEqual(normalizeAuditSeverity('warning'), 'WARNING');
assert.strictEqual(normalizeAuditSeverity('suspicious'), 'SUSPICIOUS');
assert.strictEqual(normalizeAuditSeverity('confirmed'), 'CONFIRMED');
assert.strictEqual(normalizeAuditSeverity('high'), 'CONFIRMED');
assert.strictEqual(normalizeAuditSeverity('critical'), 'CRITICAL');
assert.strictEqual(normalizeAuditSeverity('unknown'), 'WARNING');

let written;
const db = {
  collection(name) {
    assert.strictEqual(name, 'security_events');
    return {
      doc() {
        return {
          id: 'test-event-id',
          set(data) {
            written = data;
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
  reason: 'test_reason',
  details: { toolType: 'timeRewind' },
  toolType: 'timeRewind',
  status: 'rejected',
}).then(() => {
  assert.strictEqual(written.eventId, 'test-event-id');
  assert.strictEqual(written.uid, 'uid-1');
  assert.strictEqual(written.eventType, 'test_event');
  assert.strictEqual(written.severity, 'CONFIRMED');
  assert.strictEqual(written.reason, 'test_reason');
  assert.strictEqual(written.toolType, 'timeRewind');
  assert.strictEqual(written.status, 'rejected');
  assert.strictEqual(written.auditSchemaVersion, 1);
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
