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


test("Restart carries the original FREE Life debit through every replacement session", () => {
  const carry = read("supabase/migrations/20261109130000_carry_life_debit_across_restarts.sql");
  const start = read("supabase/migrations/20261106090000_restart_does_not_debit_life.sql");

  const previousDebitLookup = carry.indexOf("select life_debit_ledger_id into v_life_debit_ledger_id");
  const fallbackDebitLookup = carry.indexOf("and reason = 'NEW_GAME_DEBIT'", previousDebitLookup);
  const replacementInsert = carry.indexOf("v_start_result := public.start_game_session(");
  const debitTransfer = carry.indexOf("set life_debit_ledger_id = v_life_debit_ledger_id");

  assert.ok(previousDebitLookup >= 0 && fallbackDebitLookup > previousDebitLookup);
  assert.ok(replacementInsert > fallbackDebitLookup && debitTransfer > replacementInsert,
    "The original debit reference must be copied only after the replacement session is created.");
  assert.match(carry, /where user_id = p_user_id and game_id = p_previous_game_id[\s\S]*?for update/);
  assert.match(carry, /where user_id = p_user_id and game_id = p_game_id/);
  assert.match(start, /if p_charge_life then[\s\S]*?'NEW_GAME_DEBIT'/);
  assert.match(start, /p_initial_tiles,\s*false\s*\)/,
    "Restart must explicitly disable the ordinary new-game Life debit.");
});

test("Chapter completion refunds only an originally charged FREE Life, once, and never above five", () => {
  const carry = read("supabase/migrations/20261109130000_carry_life_debit_across_restarts.sql");
  const life = read("supabase/migrations/20261107100000_enforce_free_life_cap.sql");

  assert.match(carry, /where user_id = p_user_id\s+and id = v_session\.life_debit_ledger_id\s+and reason = 'NEW_GAME_DEBIT'/);
  assert.match(carry, /if v_life_debit_exists and\s+\(v_membership_status = 'revoked' or \(v_membership_status = 'active' and v_tier = 'FREE'\)\)/);
  assert.match(carry, /'chapter-complete-life:' \|\| p_game_id::text/);
  assert.match(carry, /if found then[\s\S]*?return coalesce\(v_existing_event\.result/);
  assert.match(carry, /v_session\.state = 'COMPLETED' and v_session\.end_reason = 'CHAPTER_COMPLETE'/);
  assert.match(life, /on conflict \(user_id, idempotency_key\) do nothing/);
  assert.match(life, /life_count = least\(5, life_count \+ 1\)/);
  assert.match(life, /check \(life_count between 0 and 5\)/);
});
