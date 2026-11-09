"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

test("tool-package purchase is server-priced, atomic, and idempotent", () => {
  const migration = read("supabase/migrations/20261105090000_atomic_tool_package_purchase.sql");
  const edge = read("supabase/functions/purchase-tool-package/index.ts");

  assert.match(migration, /create or replace function public\.purchase_tool_package/);
  assert.match(migration, /pg_advisory_xact_lock\(hashtextextended\(p_user_id::text \|\| ':' \|\| trim\(p_idempotency_key\), 0\)\)/);

  const duplicateLookup = migration.indexOf("where user_id = p_user_id and idempotency_key = v_gold_key");
  const membershipCheck = migration.indexOf("from public.memberships p");
  const goldUpdate = migration.indexOf("update public.gold_wallets");
  const toolUpdate = migration.indexOf("update public.tool_inventory");
  const goldLedger = migration.indexOf("'GOLD', null, -v_price");
  const toolLedger = migration.indexOf("'TOOL', p_tool_code, p_quantity");
  assert.ok(
    duplicateLookup >= 0 &&
      membershipCheck > duplicateLookup &&
      goldUpdate > membershipCheck &&
      toolUpdate > goldUpdate &&
      goldLedger > toolUpdate &&
      toolLedger > goldLedger,
    "Idempotency and eligibility checks must precede atomic wallet/inventory updates and both ledger entries.",
  );

  assert.match(migration, /IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD/);
  assert.match(migration, /FREE_SINGLE_TOOL_ONLY/);
  assert.match(migration, /GOLDEN_UNDO_UNLIMITED/);
  assert.match(migration, /TOOL_PACKAGE_UNAVAILABLE/);
  assert.match(migration, /TOOL_PRICE_UNAVAILABLE/);
  assert.match(migration, /INSUFFICIENT_GOLD/);
  assert.match(migration, /for update/);
  assert.match(migration, /for share/);
  assert.match(migration, /revoke all on function public\.purchase_tool_package/);
  assert.match(migration, /grant execute on function public\.purchase_tool_package[\s\S]*?to service_role/);

  assert.match(edge, /typeof quantity !== "number"/);
  assert.match(edge, /!\[1, 5, 20, 50\]\.includes\(quantity\)/);
  assert.match(edge, /idempotencyKey/);
  assert.match(edge, /rpc\("purchase_tool_package"/);
  assert.doesNotMatch(edge, /body\["priceGold"\]|body\["price"\]/);
});
