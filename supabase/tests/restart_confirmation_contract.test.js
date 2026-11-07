"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "../..");
const read = (relativePath) => fs.readFileSync(path.join(repoRoot, relativePath), "utf8");

test("Restart requires explicit confirmation before creating a replacement session", () => {
  const source = read("lib/game/screens/evolution_2048_page.dart");
  const start = source.indexOf("Future<void> _showResetMenu()");
  const end = source.indexOf("\n  Future<void> _startTool(", start);
  assert.ok(start >= 0 && end > start, "Restart handler must exist");
  const handler = source.slice(start, end);

  const dialog = handler.indexOf("showDialog<bool>(");
  const cancel = handler.indexOf("Navigator.of(dialogContext).pop(false)");
  const confirm = handler.indexOf("Navigator.of(dialogContext).pop(true)");
  const guard = handler.indexOf("if (confirmed != true || !mounted) return;");
  const reset = handler.indexOf("await _reset();");

  assert.ok(dialog >= 0, "Restart must show a confirmation dialog");
  assert.ok(cancel > dialog, "Cancel must close the dialog with false");
  assert.ok(confirm > cancel, "Confirm must close the dialog with true");
  assert.ok(guard > confirm, "The result must be checked before restarting");
  assert.ok(reset > guard, "The replacement session must only start after confirmation");
  assert.match(handler, /title: Text\(l10n\.restartConfirmTitle\)/);
  assert.match(handler, /content: Text\(l10n\.restartConfirmMessage\)/);
  assert.match(handler, /child: Text\(l10n\.cancel\)/);
  assert.match(handler, /child: Text\(l10n\.restart\)/);
});

test("Restart confirmation strings exist in English and Traditional Chinese", () => {
  const enArb = JSON.parse(read("lib/l10n/app_en.arb"));
  const zhArb = JSON.parse(read("lib/l10n/app_zh.arb"));
  const enDart = read("lib/l10n/app_localizations_en.dart");
  const zhDart = read("lib/l10n/app_localizations_zh.dart");

  for (const key of ["restartConfirmTitle", "restartConfirmMessage", "restart", "restartFailed"]) {
    assert.equal(typeof enArb[key], "string", `English ARB missing ${key}`);
    assert.equal(typeof zhArb[key], "string", `Traditional Chinese ARB missing ${key}`);
    assert.match(enDart, new RegExp(`String get ${key}\\b`));
    assert.match(zhDart, new RegExp(`String get ${key}\\b`));
  }
});

test("Supabase restart endpoint delegates settlement and start to one database RPC", () => {
  const edge = read("supabase/functions/restart-game-session/index.ts");
  const migration = read("supabase/migrations/20261103030000_atomic_restart_game_session_rpc.sql");

  assert.match(edge, /rpc\(["']restart_game_session["']/);
  assert.match(migration, /public\.abandon_game_session\(/);
  assert.match(migration, /public\.start_game_session\(/);
  assert.match(migration, /create or replace function public\.restart_game_session/);
  assert.match(migration, /pg_catalog\.hashtextextended\(p_user_id::text, 0\)/);
  const userLock = migration.indexOf("pg_catalog.pg_advisory_xact_lock(");
  const abandon = migration.indexOf("v_abandon_result := public.abandon_game_session(");
  assert.ok(userLock >= 0 && abandon > userLock,
    "Restart must acquire the per-user lock before locking and settling the previous session");
});

test("Restart validates the exact two-tile initial board before calling the RPC", () => {
  const edge = read("supabase/functions/restart-game-session/index.ts");
  assert.match(edge, /initialTiles\.length !== 16/);
  assert.match(edge, /initialTiles\.filter\(\(value\) => value !== null\)\.length !== 2/);
  assert.match(edge, /value !== null && value !== 2 && value !== 4/);
});

test("A normal start cannot bypass replay-validated settlement of an active session", () => {
  const migration = read("supabase/migrations/20261028103000_start_game_session_rpc.sql");
  const edge = read("supabase/functions/start-game-session/index.ts");

  assert.match(migration, /SESSION_ABANDON_REQUIRES_VALIDATED_SETTLEMENT/);
  assert.match(edge, /message\.includes\("SESSION_ABANDON_REQUIRES_VALIDATED_SETTLEMENT"\)/);
  assert.doesNotMatch(
    migration,
    /if v_previous\.state = 'ACTIVE' then\s+update public\.game_sessions\s+set state = 'ABANDONED'/,
    "A normal start must not abandon an active session without replay and tool settlement",
  );
});

test("Restart reconciles a lost response against the authoritative active session", () => {
  const source = read("lib/services/player_progress_service.dart");
  const start = source.indexOf("Future<bool> restartGameSession(");
  const end = source.indexOf("  Future<void> abandonGameSession(", start);
  assert.ok(start >= 0 && end > start, "Restart service method must exist");
  const method = source.slice(start, end);

  assert.match(method, /await refresh\(\);[\s\S]*?final committed = _activeGameSessionId == gameId &&\s*_activeGameChapterIndex == chapterIndex;/);
  assert.match(method, /if \(committed\) \{[\s\S]*?await ToolManager\.refreshInventory\(\);[\s\S]*?return true;/);
});

test("A restart preserves the previously charged Life while a normal start charges one", () => {
  const migration = read("supabase/migrations/20261106090000_restart_does_not_debit_life.sql");
  const startEdge = read("supabase/functions/start-game-session/index.ts");

  assert.match(migration, /p_charge_life boolean/);
  assert.match(migration, /if p_charge_life then[\s\S]*?NEW_GAME_DEBIT/);
  assert.match(migration, /from public\.life_wallets where user_id = p_user_id/);
  assert.match(migration, /p_initial_tiles,\s*false\s*\)/);
  assert.match(startEdge, /p_charge_life: true/);
});

test("Revoked membership resumes an existing session with FREE entitlements", () => {
  const resume = read("supabase/functions/resume-game-session/index.ts");
  const snapshot = read("supabase/functions/account-snapshot/index.ts");

  assert.match(resume, /\["active", "revoked"\]\.includes\(membership\.status\)/);
  assert.match(resume, /membership\.status === "revoked" \? "FREE" : membership\.tier/);
  assert.match(resume, /membershipTier: effectiveTier/);
  assert.match(snapshot, /membership\.status === "revoked" \? "FREE" : membership\.tier/);
});

test("Creature discovery requires a server-validated replay reaching each claimed value", () => {
  const endpoint = read("supabase/functions/discover-creature/index.ts");
  const client = read("lib/services/creature_collection_service.dart");
  const gameScreen = read("lib/game/screens/evolution_2048_page.dart");

  assert.match(endpoint, /\.eq\("user_id", user\.id\)/);
  assert.match(endpoint, /expectedInitialTiles: session\.initial_tiles/);
  assert.match(endpoint, /replayGame\(/);
  assert.match(endpoint, /uniqueValues\.some\(\(value\) => value > replayResult\.highestValue\)/);
  assert.match(endpoint, /\.eq\("game_id", gameId\)/);
  assert.match(client, /'replayLog': replayLog/);
  assert.match(client, /'gameId': gameId/);
  assert.match(gameScreen, /replayLog: Map<String, dynamic>\.from\(replayLog\)/);
});

test("Creature discovery remains valid after a replay-validated session ends", () => {
  const endpoint = read("supabase/functions/discover-creature/index.ts");
  assert.match(endpoint, /\["ACTIVE", "COMPLETED", "ABANDONED"\]\.includes\(session\.state\)/);
});
