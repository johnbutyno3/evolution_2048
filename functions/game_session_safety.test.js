'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const legacyBackend = fs.readFileSync(path.join(__dirname, 'game_session.js'), 'utf8');
const client = fs.readFileSync(
  path.join(__dirname, '../lib/services/player_progress_service.dart'),
  'utf8',
);
const transport = fs.readFileSync(
  path.join(__dirname, '../lib/services/supabase_game_session_service.dart'),
  'utf8',
);
const supabaseEndpoint = fs.readFileSync(
  path.join(__dirname, '../supabase/functions/restart-game-session/index.ts'),
  'utf8',
);

// Keep the archived Firebase implementation's original stale-session guard
// covered while it remains available as a migration/reference source.
const restartStart = legacyBackend.indexOf('exports.restartGameSession = onCall(');
const restartEnd = legacyBackend.indexOf('\nexports.abandonGameSession = onCall(', restartStart);
assert.notEqual(restartStart, -1, 'Legacy restart callable must remain available during migration.');
assert.ok(restartEnd > restartStart, 'Legacy restart callable boundary must exist.');
const legacyRestart = legacyBackend.slice(restartStart, restartEnd);
assert.match(
  legacyRestart,
  /const requestedSessionId = request\.data\?\.sessionId;/,
  'Legacy server must accept the previous session identity for restart.',
);
assert.match(
  legacyRestart,
  /requestedSessionId != null &&[\s\S]*?requestedSessionId !== oldSessionId/,
  'Legacy server must reject a stale/concurrent restart after the active session changes.',
);

// The active Flutter path must bind the Supabase restart to the previous
// session, and the Edge Function must validate ownership before its atomic RPC.
assert.match(
  client,
  /SupabaseGameSessionService\.restartGameSession\([\s\S]*?previousGameId:\s*previousGameId/,
  'Flutter must pass the active game ID to the Supabase restart service.',
);
assert.match(
  transport,
  /'previousGameId':\s*previousGameId/,
  'Supabase transport must include the previous game ID in its request.',
);
assert.match(
  supabaseEndpoint,
  /\.eq\("user_id",\s*user\.id\)[\s\S]*?\.eq\("game_id",\s*previousGameId\)/,
  'Supabase endpoint must scope the previous session lookup to the authenticated owner.',
);
assert.match(
  supabaseEndpoint,
  /p_previous_game_id:\s*previousGameId/,
  'Supabase RPC must receive the exact previous game ID for atomic session replacement.',
);

console.log('Game session safety contract passed: Supabase restart is bound to the authenticated previous session.');
