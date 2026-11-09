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
