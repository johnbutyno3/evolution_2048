"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("session abandonment settles tool usage once and never refunds Life", () => {
  const abandon = read("supabase/migrations/20261104010000_qualify_abandon_rpc_catalog_calls.sql");
  const restart = read("supabase/migrations/20261109113000_restart_idempotency_payload_guard.sql");

  const eventLookup = abandon.indexOf("where user_id = p_user_id and event_id = p_event_id");
  const duplicateReturn = abandon.indexOf("return coalesce(v_existing_event.result");
  const eventInsert = abandon.indexOf("insert into public.game_session_events");
  const toolSettlement = abandon.indexOf("perform public.apply_wallet_delta(");
  const sessionUpdate = abandon.indexOf("set state = 'ABANDONED'");
  assert.ok(
    eventLookup >= 0 &&
      duplicateReturn > eventLookup &&
      eventInsert > duplicateReturn &&
      toolSettlement > eventInsert &&
      sessionUpdate > toolSettlement,
    "A duplicate event must return before tool settlement; a new event settles tools before closing the session.",
  );

  assert.match(abandon, /v_usage := p_payload -> 'toolUsage'/);
  assert.match(abandon, /v_delta := v_total - v_settled/);
  assert.match(abandon, /v_tool = 'timeRewind'/);
  assert.match(abandon, /v_tier = 'GOLDEN'[\s\S]*?v_tool = 'timeRewind'/);
  assert.match(abandon, /'GAME_TOOL_USAGE'/);
  assert.match(abandon, /'game-tool-abandon:'/);
  assert.match(abandon, /Leaving or Game Over never refunds the Life already charged/);
  assert.doesNotMatch(abandon, /update public\.life_wallets/);
  assert.match(abandon, /set state = 'ABANDONED'[\s\S]*?end_reason = case/);

  const restartAbandon = restart.indexOf("v_abandon_result := public.abandon_game_session(");
  const restartStart = restart.indexOf("v_start_result := public.start_game_session(");
  assert.ok(restartAbandon >= 0 && restartStart > restartAbandon);
  assert.match(restart, /p_initial_tiles,\s*false\s*\)/);
});
