"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("chapter completion atomically validates, settles, unlocks, and refunds Life once", () => {
  const migration = read("supabase/migrations/20261028120000_finish_game_chapter_rpc.sql");
  const edge = read("supabase/functions/finish-game-chapter/index.ts");

  const duplicateLookup = migration.indexOf("where user_id = p_user_id and event_id = p_event_id");
  const duplicateReturn = migration.indexOf("return coalesce(v_existing_event.result");
  const eventInsert = migration.indexOf("insert into public.game_session_events");
  const toolSettlement = migration.indexOf("perform public.apply_wallet_delta(");
  const progressUpdate = migration.indexOf("insert into public.game_progress");
  const lifeRefund = migration.indexOf("v_life_result := public.apply_life_delta(");
  const sessionComplete = migration.indexOf("set state = 'COMPLETED'");
  assert.ok(
    duplicateLookup >= 0 &&
      duplicateReturn > duplicateLookup &&
      eventInsert > duplicateReturn &&
      toolSettlement > eventInsert &&
      progressUpdate > toolSettlement &&
      lifeRefund > progressUpdate &&
      sessionComplete > lifeRefund,
    "Duplicate events must return early; a new completion settles tools, progress and Life in one transaction.",
  );

  assert.match(migration, /v_stage_count := v_chapter_index \+ 12/);
  assert.match(migration, /v_target := pg_catalog\.power\(2::numeric, v_stage_count\)::bigint/);
  assert.match(migration, /v_highest < v_target/);
  assert.match(migration, /v_life_debit_exists/);
  assert.match(migration, /'NEW_GAME_DEBIT'/);
  assert.match(migration, /v_life_debit_exists and[\s\S]*?v_membership_status = 'active' and v_tier = 'FREE'/);
  assert.match(migration, /'CHAPTER_COMPLETE_REFUND'/);
  assert.match(migration, /'chapter-complete-life:'/);
  assert.match(migration, /v_tier = 'GOLDEN'[\s\S]*?v_replay_tool = 'timeRewind'/);
  assert.match(migration, /CHAPTER_ALREADY_COMPLETED_WITH_DIFFERENT_EVENT/);
  assert.match(migration, /revoke all on function public\.finish_game_chapter/);
  assert.match(migration, /grant execute on function public\.finish_game_chapter[\s\S]*?to service_role/);

  const replay = edge.indexOf("replayGame({");
  const rpc = edge.indexOf('service.rpc("finish_game_chapter"');
  assert.ok(replay >= 0 && rpc > replay,
    "The Edge Function must replay-validate before invoking the settlement RPC.");
});
