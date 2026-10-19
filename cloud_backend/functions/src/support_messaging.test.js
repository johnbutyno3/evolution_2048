'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../../..');
const source = fs.readFileSync(path.join(__dirname, 'support_messaging.js'), 'utf8');
const index = fs.readFileSync(path.join(__dirname, 'index.js'), 'utf8');
const rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');

for (const callable of [
  'openSupportCase',
  'sendSupportMessage',
  'listMySupportCases',
  'listSupportMessages',
  'listSupportCasesAdmin',
  'setSupportCaseStatusAdmin',
]) {
  assert.match(
    source,
    new RegExp(`exports\\.${callable}\\s*=\\s*onCall\\s*\\(`),
    `Missing support callable: ${callable}`,
  );
  assert.match(index, new RegExp(`require\\(['"]\\./support_messaging['"]\\)`));
}

assert.match(source, /Authentication is required|Sign in is required/);
assert.match(source, /supportCase\.uid !== uid/);
assert.match(source, /if \(!isAdmin\)/);
assert.match(source, /This support case belongs to another account/);
assert.match(source, /MAX_MESSAGE_LENGTH = 4000/);
assert.match(source, /MAX_SUBJECT_LENGTH = 160/);
const sendStart = source.indexOf('exports.sendSupportMessage = onCall(');
const sendEnd = source.indexOf('exports.listMySupportCases = onCall(', sendStart);
assert.notEqual(sendStart, -1, 'sendSupportMessage callable must exist.');
assert.notEqual(sendEnd, -1, 'sendSupportMessage callable boundary must exist.');
const sendCallable = source.slice(sendStart, sendEnd);
assert.match(sendCallable, /db\.runTransaction\(async \(transaction\)/,
  'Case status validation and message append must be atomic.');
assert.match(sendCallable, /transaction\.get\(ref\)/);
assert.match(sendCallable, /transaction\.create\(messageRef/);
assert.match(sendCallable, /supportCase\.status === 'closed'/);

assert.doesNotMatch(source, /enforceSensitiveOperation\(/,
  'Support callables must remain available when gameplay operations are locked.');
assert.match(rules, /match \/support_cases\/\{caseId\}/);
assert.match(rules, /match \/messages\/\{messageId\} \{\s*allow read, write: if false;/);
console.log('Support messaging safety contract OK.');
