const assert = require('assert');
const fs = require('fs');
const path = require('path');

const migration = fs.readFileSync(
  path.join(__dirname, 'migrate_security_audit_integration.js'),
  'utf8',
);

assert.ok(migration.includes("recordSecurityEvent: recordAuditEvent"));
assert.ok(migration.includes('function recordSecurityEvent({ uid, action'));
assert.ok(migration.includes('return recordAuditEvent(db, {'));
assert.ok(migration.includes('Legacy securityEventRef remains after migration.'));
assert.ok(migration.includes('Legacy security audit block exists but does not match'));
assert.ok(migration.includes('Unexpected functions/index.js structure'));
assert.ok(migration.includes('Security audit helper is not called with the Firestore db instance.'));

console.log('Security audit migration guard checks passed.');
