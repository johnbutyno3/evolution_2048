"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("replay and tool settlement discrepancies are recorded for review, not auto-locks", () => {
  const finish = read("supabase/functions/finish-game-chapter/index.ts");
  const abandon = read("supabase/functions/abandon-game-session/index.ts");
  const restart = read("supabase/functions/restart-game-session/index.ts");
  const helper = read("supabase/functions/_shared/security_events.ts");
  const migration = read("supabase/migrations/20261109120000_security_event_idempotency.sql");

  for (const source of [finish, abandon, restart]) {
    assert.match(source, /recordSecurityEvent\(/);
    assert.doesNotMatch(source, /lock_account_for_security_violation/);
    assert.match(source, /TOOL_USAGE_REQUIRES_REVIEW/);
  }

  assert.match(finish, /replay_validation_failed/);
  assert.match(finish, /REPLAY_VALIDATION_FAILED/);
  assert.match(finish, /}, 409\)/);
  assert.match(helper, /idempotency_key: `\$\{eventId\}:\$\{reason\}`/);
  assert.match(helper, /onConflict: "user_id,idempotency_key"/);
  assert.match(helper, /ignoreDuplicates: true/);
  assert.match(migration, /add column if not exists idempotency_key text/);
  assert.match(migration, /create unique index if not exists security_events_user_idempotency_key_uidx/);
});
