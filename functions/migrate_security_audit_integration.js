const fs = require('fs');
const path = require('path');

const indexPath = path.join(__dirname, 'index.js');
const source = fs.readFileSync(indexPath, 'utf8');

const importLine = "const { recordSecurityEvent: recordAuditEvent } = require('./security_audit');";
const compatibilityWrapper = `function recordSecurityEvent({ uid, action, severity = 'warning', reason, details = {} }) {\n  return recordAuditEvent(db, {\n    uid,\n    action,\n    severity,\n    reason,\n    details,\n  });\n}\n`;
const legacyBlock = `function securityEventRef() {\n  return db.collection('security_events').doc();\n}\n\nfunction recordSecurityEvent({ uid, action, severity = 'warning', reason, details = {} }) {\n  return securityEventRef().set({\n    uid: typeof uid === 'string' ? uid : null,\n    action,\n    severity,\n    reason,\n    details,\n    createdAt: FieldValue.serverTimestamp(),\n  }).catch(() => null);\n}\n`;

if (!source.includes("require('./replay_validator')")) {
  throw new Error('Unexpected functions/index.js structure: replay_validator import not found.');
}

if (!source.includes(importLine)) {
  const marker = "const { replayGame, allowedToolsForChapter } = require('./replay_validator');";
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) {
    throw new Error('Unable to locate replay_validator import marker.');
  }
  const insertionPoint = markerIndex + marker.length;
  const updated = `${source.slice(0, insertionPoint)}\n${importLine}${source.slice(insertionPoint)}`;
  fs.writeFileSync(indexPath, updated, 'utf8');
}

let current = fs.readFileSync(indexPath, 'utf8');
if (current.includes(legacyBlock)) {
  current = current.replace(legacyBlock, compatibilityWrapper);
  fs.writeFileSync(indexPath, current, 'utf8');
} else if (current.includes('function securityEventRef()')) {
  throw new Error('Legacy security audit block exists but does not match the expected canonical form. Stop for manual review.');
} else if (!current.includes(compatibilityWrapper)) {
  throw new Error('Security audit wrapper is missing and the legacy block is already absent. Stop for manual review.');
}

const finalSource = fs.readFileSync(indexPath, 'utf8');
if (!finalSource.includes(importLine)) {
  throw new Error('Security audit helper import was not installed.');
}
if (!finalSource.includes(compatibilityWrapper)) {
  throw new Error('Security audit compatibility wrapper was not installed.');
}
if (finalSource.includes('function securityEventRef()')) {
  throw new Error('Legacy securityEventRef remains after migration.');
}
if (!finalSource.includes('recordAuditEvent(db, {')) {
  throw new Error('Security audit helper is not called with the Firestore db instance.');
}

console.log('Security audit integration migration completed.');
