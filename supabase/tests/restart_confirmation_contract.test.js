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
  const migration = read("supabase/migrations/20261109113000_restart_idempotency_payload_guard.sql");

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
  const migration = read("supabase/migrations/20261106090000_restart_does_not_debit_life.sql");
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
  const start = source.indexOf("Future<RestartGameSessionResult> restartGameSession(");
  const end = source.indexOf("  Future<bool> abandonGameSession(", start);
  assert.ok(start >= 0 && end > start, "Restart service method must exist");
  const method = source.slice(start, end);

  assert.match(method, /final requestId = _newUuid\(\);[\s\S]*?requestId: requestId/);
  assert.match(method, /await refresh\(\);[\s\S]*?_activeGameSessionId == gameId[\s\S]*?_activeGameRequestId == requestId/);
  const snapshot = read("supabase/functions/account-snapshot/index.ts");
  const parser = read("lib/services/supabase_account_service.dart");
  assert.match(snapshot, /select\("game_id, request_id, chapter_code/);
  assert.match(snapshot, /requestId: activeSession\.request_id/);
  assert.match(parser, /activeGameRequestId = rawActiveSession\['requestId'\] as String/);
  assert.match(method, /if \(_activeGameSessionId == gameId[\s\S]*?await ToolManager\.refreshInventory\(\);[\s\S]*?return RestartGameSessionResult\.committed;/);
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

test("FREE life wallets and trusted adjustments are capped at five lives", () => {
  const migration = read("supabase/migrations/20261107100000_enforce_free_life_cap.sql");
  const importMigration = read("supabase/migrations/20261105120000_legacy_account_import.sql");

  assert.match(migration, /add constraint life_wallets_life_count_check check \(life_count between 0 and 5\)/);
  assert.match(migration, /set life_count = least\(5, greatest\(0, life_count\)\)/);
  assert.match(migration, /set life_count = least\(5, greatest\(0, life_count \+ p_quantity_delta\)\)/);
  assert.doesNotMatch(migration, /trusted adjustments may grant bonus lives above 5/i);
  assert.match(importMigration, /life_count = 5 and next_regen_at is null/);
});

test("Tool purchase idempotency key survives app restarts", () => {
  const service = read("lib/services/supabase_tool_purchase_service.dart");
  assert.match(service, /SharedPreferences\.getInstance\(\)/);
  assert.match(service, /supabase_pending_tool_purchase:/);
  assert.match(service, /final requestId = await _requestIdFor\(requestKey\)/);
  assert.match(service, /await preferences\.remove\(storageKey\)/);
  assert.match(service, /supabase_pending_tool_purchase:\$requestKey/);
  assert.match(service, /\$\{client\.auth\.currentUser!\.id\}:\$toolCode:\$quantity/);
  assert.match(service, /setBool\('\$storageKey:completed', true\)/);
  assert.match(service, /Purchase protection could not be saved/);
});


test("Account bootstrap syncs a validated device IANA timezone before daily Gold claim", () => {
  const client = read("lib/services/supabase_account_service.dart");
  const endpoint = read("supabase/functions/account-snapshot/index.ts");
  const dailyGold = read("supabase/migrations/20261028100000_daily_gold_claim_rpc.sql");
  const timezoneRpc = read("supabase/migrations/20261107120000_set_account_timezone_rpc.sql");
  assert.match(client, /FlutterTimezone.getLocalTimezone\(\)/);
  assert.match(client, /info.identifier/);
  assert.match(client, /'timezone': deviceTimezone/);
  assert.match(endpoint, /typeof body.timezone === "string"/);
  assert.match(endpoint, /new Intl.DateTimeFormat\("en-US", \{ timeZone: timezone \}\)/);
  const update = endpoint.indexOf("set_account_timezone");
  const claim = endpoint.indexOf('rpc("claim_daily_gold"');
  assert.ok(update >= 0 && claim > update, "Timezone must be saved before the daily Gold claim");
  assert.match(dailyGold, /now\(\) at time zone v_timezone/);
  assert.match(timezoneRpc, /pg_catalog\.pg_timezone_names/);
  assert.ok(timezoneRpc.includes("as $$\ndeclare\n  v_current_timezone text;"), "Timezone RPC must declare its local variable inside a valid dollar-quoted function");
  assert.ok(timezoneRpc.includes("\n$$;"), "Timezone RPC must close its dollar-quoted function");
  assert.match(timezoneRpc, /created_at > now\(\) - interval '24 hours'/);
  assert.match(timezoneRpc, /grant execute on function public\.set_account_timezone\(uuid, text\) to service_role/);
  assert.match(timezoneRpc, /revoke all on function public\.set_account_timezone\(uuid, text\) from public, anon, authenticated/);
});


test("Membership and real-money purchase records are not client-writable", () => {
  const permissions = read("supabase/migrations/20261107130000_lock_membership_purchase_writes.sql");
  assert.match(permissions, /revoke insert, update, delete on table public\.memberships\s+from public, anon, authenticated/);
  assert.match(permissions, /revoke insert, update, delete on table public\.purchase_transactions\s+from public, anon, authenticated/);
  assert.match(permissions, /grant all on table public\.memberships, public\.purchase_transactions\s+to service_role/);
});


test("Premium to Golden upgrade price is wired through config, admin, and membership UI", () => {
  const shop = read("lib/services/shop_config_service.dart");
  const adminService = read("lib/services/admin_service.dart");
  const adminPage = read("lib/screens/admin_page.dart");
  const adminFunction = read("supabase/functions/admin-update-shop-config/index.ts");
  const membershipPage = read("lib/screens/membership_page.dart");
  const catalog = read("supabase/migrations/20261028113000_shop_config.sql");
  assert.match(shop, /'goldenUpgradeUsdPrice': '3\.00'/);
  assert.match(shop, /'membership_upgrade_golden': 'goldenUpgradeUsdPrice'/);
  assert.match(adminService, /'goldenUpgradeUsdPrice': \('membership_upgrade_golden', 'priceUsd'\)/);
  assert.match(adminPage, /Premium → Golden Upgrade USD/);
  assert.match(adminFunction, /goldenUpgradeUsdPrice: \{ product: "membership_upgrade_golden", field: "priceUsd"/);
  assert.match(membershipPage, /current == 'premium'/);
  assert.match(membershipPage, /'goldenUpgradeUsdPrice'/);
  assert.match(catalog, /"membership_upgrade_golden".*"priceUsd":"3\.00"/);
});


test("Real-money membership checkout remains blocked until store verification is implemented", () => {
  const page = read("lib/screens/membership_page.dart");
  assert.match(page, /Real-money payment is not connected yet/);
  assert.match(page, /onPressed: _unavailable/);
  assert.doesNotMatch(page, /functions\.invoke|purchase-membership|verify-store-purchase/);

test("Restart writes the replacement board before the RPC and recovers by server session ID", () => {
  const service = read("lib/services/player_progress_service.dart");
  const screen = read("lib/game/screens/evolution_2048_page.dart");
  const save = read("lib/game/services/save_manager.dart");

  const restartStart = service.indexOf("Future<RestartGameSessionResult> restartGameSession(");
  const restartEnd = service.indexOf("Future<bool> abandonGameSession(", restartStart);
  assert.ok(restartStart >= 0 && restartEnd > restartStart);
  const restart = service.slice(restartStart, restartEnd);
  const bind = restart.indexOf("await SaveManager.setGameSessionId(gameId)");
  const persist = restart.indexOf("await SaveManager.save(candidateSave)");
  const rpc = restart.indexOf("SupabaseGameSessionService.restartGameSession(");
  assert.ok(bind >= 0 && persist > bind && rpc > persist,
    "The replacement board and binding must be durable before the restart RPC begins.");

  assert.match(restart, /RestartGameSessionResult\.pending/);
  assert.match(restart, /_activeGameRequestId == requestId/);
  assert.match(service, /SaveManager\.restoreSnapshotForSession\(/);

  assert.match(screen, /replacementSave: replacementSave/);
  assert.match(screen, /result == RestartGameSessionResult\.pending/);
  assert.match(screen, /restartResult == RestartGameSessionResult\.pending/);

  assert.match(save, /_saveSlotAKey/);
  assert.match(save, /_saveSlotBKey/);
  assert.match(save, /restoreSnapshotForSession/);
  assert.match(save, /_preferences!\.setInt\(_savePointerKey, slot\)/);
});


test("Restart idempotency validates the prior session and abandon event before settlement", () => {
  const migration = read("supabase/migrations/20261109113000_restart_idempotency_payload_guard.sql");
  const requestLookup = migration.indexOf("where user_id = p_user_id and request_id = p_request_id");
  const eventLookup = migration.indexOf("where user_id = p_user_id and event_id = p_abandon_event_id");
  const abandon = migration.indexOf("v_abandon_result := public.abandon_game_session(");

  assert.ok(requestLookup >= 0 && eventLookup > requestLookup && abandon > eventLookup,
    "The exact request and abandon event must be checked before settling the previous session.");
  assert.match(migration, /v_existing\.game_id <> p_game_id/);
  assert.match(migration, /v_existing\.chapter_code <> p_chapter_code/);
  assert.match(migration, /v_existing\.initial_tiles is distinct from p_initial_tiles/);
  assert.match(migration, /v_existing_event\.game_id <> p_previous_game_id/);
  assert.match(migration, /v_existing_event\.event_type <> 'SESSION_ABANDON'/);
  assert.match(migration, /v_existing_event\.payload is distinct from p_abandon_payload/);
  assert.match(migration, /else[\s\S]*?where user_id = p_user_id and event_id = p_abandon_event_id[\s\S]*?if found then[\s\S]*?IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD/);
  assert.match(migration, /IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD/);
});

});
