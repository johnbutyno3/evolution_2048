-- Trusted, atomic tool-package purchases.
-- Prices and eligibility are evaluated server-side; never trust client-supplied prices.

update public.shop_config
set products = products || '{
  "tool_undo_1":{"type":"tool","toolCode":"UNDO","quantity":1,"priceGold":50,"active":true},
  "tool_undo_5":{"type":"tool","toolCode":"UNDO","quantity":5,"priceGold":225,"active":true},
  "tool_undo_20":{"type":"tool","toolCode":"UNDO","quantity":20,"priceGold":700,"active":true},
  "tool_undo_50":{"type":"tool","toolCode":"UNDO","quantity":50,"priceGold":1500,"active":true},
  "tool_remove_1":{"type":"tool","toolCode":"REMOVE","quantity":1,"priceGold":100,"active":true},
  "tool_remove_5":{"type":"tool","toolCode":"REMOVE","quantity":5,"priceGold":450,"active":true},
  "tool_remove_20":{"type":"tool","toolCode":"REMOVE","quantity":20,"priceGold":1400,"active":true},
  "tool_remove_50":{"type":"tool","toolCode":"REMOVE","quantity":50,"priceGold":3000,"active":true},
  "tool_swap_1":{"type":"tool","toolCode":"SWAP","quantity":1,"priceGold":200,"active":true},
  "tool_swap_5":{"type":"tool","toolCode":"SWAP","quantity":5,"priceGold":900,"active":true},
  "tool_swap_20":{"type":"tool","toolCode":"SWAP","quantity":20,"priceGold":2800,"active":true},
  "tool_swap_50":{"type":"tool","toolCode":"SWAP","quantity":50,"priceGold":6000,"active":true},
  "tool_duplicate_1":{"type":"tool","toolCode":"DUPLICATE","quantity":1,"priceGold":500,"active":true},
  "tool_duplicate_5":{"type":"tool","toolCode":"DUPLICATE","quantity":5,"priceGold":2250,"active":true},
  "tool_duplicate_20":{"type":"tool","toolCode":"DUPLICATE","quantity":20,"priceGold":7000,"active":true},
  "tool_duplicate_50":{"type":"tool","toolCode":"DUPLICATE","quantity":50,"priceGold":15000,"active":true}
}'::jsonb
where id = 'global';

create or replace function public.purchase_tool_package(
  p_user_id uuid,
  p_tool_code text,
  p_quantity bigint,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier text;
  v_membership_status text;
  v_account_status text;
  v_product_key text;
  v_product jsonb;
  v_price bigint;
  v_gold bigint;
  v_tools bigint;
  v_gold_key text;
  v_tool_key text;
  v_gold_ledger public.wallet_ledger%rowtype;
  v_tool_ledger public.wallet_ledger%rowtype;
begin
  if p_user_id is null
    or p_tool_code is null
    or p_quantity is null
    or p_tool_code not in ('UNDO', 'REMOVE', 'SWAP', 'DUPLICATE')
    or p_quantity not in (1, 5, 20, 50)
    or p_idempotency_key is null
    or length(trim(p_idempotency_key)) < 16
    or length(p_idempotency_key) > 200 then
    raise exception using errcode = '22023', message = 'INVALID_TOOL_PURCHASE';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':' || trim(p_idempotency_key), 0));

  v_gold_key := trim(p_idempotency_key) || ':gold';
  v_tool_key := trim(p_idempotency_key) || ':tool';

  select * into v_gold_ledger
  from public.wallet_ledger
  where user_id = p_user_id and idempotency_key = v_gold_key;

  select * into v_tool_ledger
  from public.wallet_ledger
  where user_id = p_user_id and idempotency_key = v_tool_key;

  if v_gold_ledger.id is not null or v_tool_ledger.id is not null then
    if v_gold_ledger.id is null or v_tool_ledger.id is null
      or v_gold_ledger.asset_type <> 'GOLD'
      or v_gold_ledger.asset_code is not null
      or v_gold_ledger.reason <> 'TOOL_PACKAGE_PURCHASE'
      or v_tool_ledger.asset_type <> 'TOOL'
      or v_tool_ledger.asset_code <> p_tool_code
      or v_tool_ledger.reason <> 'TOOL_PACKAGE_PURCHASE'
      or v_gold_ledger.quantity_delta >= 0
      or v_tool_ledger.quantity_delta <> p_quantity
      or v_gold_ledger.metadata ->> 'toolCode' <> p_tool_code
      or (v_gold_ledger.metadata ->> 'quantity')::bigint <> p_quantity then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;

    select balance into v_gold from public.gold_wallets where user_id = p_user_id;
    select quantity into v_tools from public.tool_inventory
      where user_id = p_user_id and tool_code = p_tool_code;
    return jsonb_build_object(
      'duplicate', true,
      'toolCode', p_tool_code,
      'quantity', p_quantity,
      'priceGold', -v_gold_ledger.quantity_delta,
      'balance', v_gold,
      'uses', v_tools
    );
  end if;

  select p.tier, p.status, pr.account_status
    into v_tier, v_membership_status, v_account_status
  from public.memberships p
  join public.profiles pr on pr.user_id = p.user_id
  where p.user_id = p_user_id
  for share of p, pr;

  if v_account_status is distinct from 'active' then
    raise exception using errcode = '42501', message = 'ACCOUNT_RESTRICTED';
  end if;
  if v_membership_status = 'under_review' then
    raise exception using errcode = '42501', message = 'MEMBERSHIP_REQUIRES_REVIEW';
  end if;
  if v_membership_status is distinct from 'active' then
    v_tier := 'FREE';
  end if;

  if v_tier = 'FREE' and p_quantity <> 1 then
    raise exception using errcode = '22023', message = 'FREE_SINGLE_TOOL_ONLY';
  end if;
  if v_tier = 'GOLDEN' and p_tool_code = 'UNDO' then
    raise exception using errcode = '22023', message = 'GOLDEN_UNDO_UNLIMITED';
  end if;

  v_product_key := 'tool_' || lower(p_tool_code) || '_' || p_quantity::text;
  select products -> v_product_key into v_product
  from public.shop_config where id = 'global' for share;

  if v_product is null
    or coalesce((v_product ->> 'active')::boolean, false) is not true
    or v_product ->> 'type' <> 'tool'
    or v_product ->> 'toolCode' <> p_tool_code
    or (v_product ->> 'quantity')::bigint <> p_quantity then
    raise exception using errcode = '22023', message = 'TOOL_PACKAGE_UNAVAILABLE';
  end if;

  v_price := (v_product ->> 'priceGold')::bigint;
  if v_price is null or v_price <= 0 then
    raise exception using errcode = '22023', message = 'TOOL_PRICE_UNAVAILABLE';
  end if;

  select balance into v_gold
  from public.gold_wallets where user_id = p_user_id for update;
  select quantity into v_tools
  from public.tool_inventory
  where user_id = p_user_id and tool_code = p_tool_code for update;

  if v_gold is null or v_tools is null then
    raise exception using errcode = '23503', message = 'ACCOUNT_WALLET_MISSING';
  end if;
  if v_gold < v_price then
    raise exception using errcode = '23514', message = 'INSUFFICIENT_GOLD';
  end if;

  update public.gold_wallets
    set balance = balance - v_price
    where user_id = p_user_id
    returning balance into v_gold;

  update public.tool_inventory
    set quantity = quantity + p_quantity
    where user_id = p_user_id and tool_code = p_tool_code
    returning quantity into v_tools;

  insert into public.wallet_ledger (
    user_id, asset_type, asset_code, quantity_delta, reason,
    idempotency_key, metadata
  ) values (
    p_user_id, 'GOLD', null, -v_price, 'TOOL_PACKAGE_PURCHASE',
    v_gold_key,
    jsonb_build_object('toolCode', p_tool_code, 'quantity', p_quantity, 'priceGold', v_price)
  );

  insert into public.wallet_ledger (
    user_id, asset_type, asset_code, quantity_delta, reason,
    idempotency_key, metadata
  ) values (
    p_user_id, 'TOOL', p_tool_code, p_quantity, 'TOOL_PACKAGE_PURCHASE',
    v_tool_key,
    jsonb_build_object('toolCode', p_tool_code, 'quantity', p_quantity, 'priceGold', v_price)
  );

  return jsonb_build_object(
    'duplicate', false,
    'toolCode', p_tool_code,
    'quantity', p_quantity,
    'priceGold', v_price,
    'balance', v_gold,
    'uses', v_tools
  );
end;
$$;

revoke all on function public.purchase_tool_package(uuid, text, bigint, text)
  from public, anon, authenticated;
grant execute on function public.purchase_tool_package(uuid, text, bigint, text)
  to service_role;
