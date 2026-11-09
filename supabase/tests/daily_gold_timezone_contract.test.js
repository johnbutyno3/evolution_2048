"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("daily Gold claim serializes timezone read against timezone changes", () => {
  const claim = read("supabase/migrations/20261109123000_lock_timezone_during_daily_claim.sql");
  const timezone = read("supabase/migrations/20261107120000_set_account_timezone_rpc.sql");

  const timezoneRead = claim.indexOf("select timezone_name into v_timezone");
  const profileShareLock = claim.indexOf("for share", timezoneRead);
  const dateCalculation = claim.indexOf("v_claim_date :=");
  const claimInsert = claim.indexOf("insert into public.daily_gold_claims");
  const walletCredit = claim.indexOf("v_ledger := public.apply_wallet_delta(");
  assert.ok(
    timezoneRead >= 0 &&
      profileShareLock > timezoneRead &&
      dateCalculation > profileShareLock &&
      claimInsert > dateCalculation &&
      walletCredit > claimInsert,
    "The profile timezone must remain locked from date calculation through the daily claim and wallet credit.",
  );

  assert.match(timezone, /from public\.profiles[\s\S]*?for update/);
  assert.match(timezone, /from public\.daily_gold_claims[\s\S]*?created_at > now\(\) - interval '24 hours'/);
  assert.match(claim, /on conflict \(user_id, claim_date\) do nothing/);
  assert.match(claim, /daily-gold:' \|\| v_claim_date::text/);
});
