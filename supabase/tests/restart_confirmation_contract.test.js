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
