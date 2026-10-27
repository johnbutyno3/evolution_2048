'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const backend = fs.readFileSync(path.join(__dirname, 'game_session.js'), 'utf8');
const client = fs.readFileSync(
  path.join(__dirname, '../lib/services/player_progress_service.dart'),
  'utf8',
);

const restartStart = backend.indexOf('exports.restartGameSession = onCall(');
const restartEnd = backend.indexOf('\nexports.abandonGameSession = onCall(', restartStart);
assert.notEqual(restartStart, -1, 'Restart callable must exist.');
assert.ok(restartEnd > restartStart, 'Restart callable boundary must exist.');
const restart = backend.slice(restartStart, restartEnd);

assert.match(
  restart,
  /const requestedSessionId = request\.data\?\.sessionId;/,
  'Server must accept the previous session identity for restart.',
);
assert.match(
  restart,
  /requestedSessionId != null &&[\s\S]*?requestedSessionId !== oldSessionId/,
  'Server must reject a stale/concurrent restart after the active session changes.',
);

const callStart = client.indexOf("_functions.httpsCallable('restartGameSession').call({");
const callEnd = client.indexOf('\n      });', callStart);
assert.notEqual(callStart, -1, 'Flutter restart call must exist.');
assert.ok(callEnd > callStart, 'Flutter restart payload boundary must exist.');
const payload = client.slice(callStart, callEnd);
assert.match(
  payload,
  /'sessionId':\s*\?previousSessionId/,
  'Flutter must bind restart to the active session it intends to replace.',
);

console.log('Game session safety contract passed: restart is bound to the replaced session.');
