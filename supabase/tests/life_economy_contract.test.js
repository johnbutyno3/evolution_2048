"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("FREE Life regeneration uses server time, 40-minute catch-up, and a hard cap of five", () => {
  const regen = read("supabase/migrations/20261028094500_life_regeneration_rpc.sql");
  const life = read("supabase/migrations/20261107100000_enforce_free_life_cap.sql");
  const start = read("supabase/migrations/20261106090000_restart_does_not_debit_life.sql");
  const carry = read("supabase/migrations/20261109130000_carry_life_debit_across_restarts.sql");
  const completion = carry;

  assert.match(regen, /extract\(epoch from \(now\(\) - v_next_regen_at\)\) \/ 2400/);
  assert.match(regen, /least\(5 - v_lives, v_periods\)/);
  assert.match(regen, /when v_new_lives >= 5 then null/);
  assert.match(regen, /'life-regen:'/);
  assert.match(regen, /for update/);
  assert.match(life, /check \(life_count between 0 and 5\)/);
  assert.match(life, /life_count = least\(5, life_count \+ 1\)/);
  assert.match(start, /v_regen_result := public\.regenerate_lives\(p_user_id\)/);
  assert.match(start, /if p_charge_life then[\s\S]*?public\.apply_life_delta\(/);
  assert.match(completion, /v_life_debit_exists/);
  assert.match(completion, /'CHAPTER_COMPLETE_REFUND'/);
  assert.match(carry, /add column if not exists life_debit_ledger_id uuid/);
  assert.match(carry, /before insert on public\.game_sessions/);
  assert.match(carry, /select life_debit_ledger_id into v_life_debit_ledger_id/);
  assert.match(carry, /set life_debit_ledger_id = v_life_debit_ledger_id/);
  assert.match(carry, /id = v_session\.life_debit_ledger_id/);
});
