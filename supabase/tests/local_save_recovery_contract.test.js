"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("local save snapshots use a checksummed double buffer and committed pointer", () => {
  const source = read("lib/game/services/save_manager.dart");

  assert.match(source, /_saveSlotAKey/);
  assert.match(source, /_saveSlotBKey/);
  assert.match(source, /_savePointerKey/);
  assert.match(source, /formatVersion': 2/);
  assert.match(source, /'sequence': nextSequence/);
  assert.match(source, /'checksum': _checksum\(payloadJson\)/);
  assert.match(source, /_checksum\(jsonEncode\(payload\)\) != decoded\['checksum'\]/);

  const persistStart = source.indexOf("static Future<void> _persistSnapshotNow(");
  const persistEnd = source.indexOf("static Future<void> _rebindCachedGameSessionNow(", persistStart);
  assert.ok(persistStart >= 0 && persistEnd > persistStart);
  const persist = source.slice(persistStart, persistEnd);
  const slotWrite = persist.indexOf("setString(targetKey, envelope)");
  const pointerWrite = persist.indexOf("setInt(");
  assert.ok(slotWrite >= 0 && pointerWrite > slotWrite,
    "The inactive snapshot slot must be written before the active pointer is committed.");
});

test("local save recovery falls back to the previous committed snapshot and legacy data", () => {
  const source = read("lib/game/services/save_manager.dart");
  assert.match(source, /if \(pointer == 0 && slotA != null\)/);
  assert.match(source, /else if \(pointer == 1 && slotB != null\)/);
  assert.match(source, /_cachedSave = _decode\(_preferences\?\.getString\(_saveKey\)\)/);
  assert.match(source, /static Future<void> _persistSnapshotNow\(/);
});

test("a failed GameEngine autosave does not permanently poison later saves", () => {
  const source = read("lib/game/services/game_engine.dart");
  const start = source.indexOf("void _saveLocal()");
  const end = source.indexOf("Future<void> flushLocalSave()", start);
  assert.ok(start >= 0 && end > start);
  const method = source.slice(start, end);
  assert.match(method, /_saveQueue = _saveQueue\.then\(/);
  assert.match(method, /\(_, _\) => SaveManager\.save\(snapshot\)/);
});

test("a first local game board is persisted and bound before background session creation", () => {
  const service = read("lib/services/player_progress_service.dart");
  const screen = read("lib/game/screens/evolution_2048_page.dart");

  const start = service.indexOf("Future<bool> startGameSession(");
  const end = service.indexOf("Future<bool> _startGameSessionOnServer(", start);
  assert.ok(start >= 0 && end > start);
  const method = service.slice(start, end);
  const bind = method.indexOf("await SaveManager.setGameSessionId(gameId)");
  const save = method.indexOf("await SaveManager.save(candidateSave)");
  const launch = method.indexOf("_startGameSessionOnServer(");
  assert.ok(bind >= 0 && save > bind && launch > save,
    "The local board must be durable before the backend start request is launched.");

  assert.match(method, /initialSave/);
  assert.match(screen, /initialSave: newSave/);
  assert.match(screen, /await progress\.startGameSession\(/);
  assert.match(screen, /progress\.waitForPendingStartSession\(\)/);
});
