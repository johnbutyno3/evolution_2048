-- Atomic, idempotent primitive for trusted Edge Functions only.
-- Business-specific authorization and transaction verification must happen
-- before calling this function. Never expose a generic balance mutation API
-- to authenticated clients.

create or replace function public.apply_wallet_delta(
  p_user_id uuid,
  p_asset_type text,
  p_asset_code text,
  p_quantity_delta bigint,
  p_reason text,
  p_idempotency_key text,
  p_related_transaction_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ledger_id uuid;
  v_existing public.wallet_ledger%rowtype;
  v_new_balance bigint;
begin
  if p_user_id is null
    or p_quantity_delta is null
    or p_quantity_delta = 0
    or p_reason is null
    or length(trim(p_reason)) = 0
    or p_idempotency_key is null
    or length(trim(p_idempotency_key)) = 0
    or length(p_idempotency_key) > 200 then
    raise exception using errcode = '22023', message = 'INVALID_WALLET_OPERATION';
  end if;

  if p_asset_type = 'GOLD' then
    if p_asset_code is not null then
      raise exception using errcode = '22023', message = 'INVALID_GOLD_ASSET_CODE';
    end if;
  elsif p_asset_type = 'TOOL' then
    if p_asset_code not in ('UNDO', 'REMOVE', 'SWAP', 'DUPLICATE') then
      raise exception using errcode = '22023', message = 'INVALID_TOOL_CODE';
    end if;
  else
    raise exception using errcode = '22023', message = 'UNSUPPORTED_ASSET_TYPE';
  end if;

  -- Reserve the idempotency key before changing the balance. A concurrent
  -- duplicate blocks on the unique key and then exits without applying delta.
  insert into public.wallet_ledger (
    user_id, asset_type, asset_code, quantity_delta, reason,
    idempotency_key, related_transaction_id, metadata
  )
  values (
    p_user_id, p_asset_type, p_asset_code, p_quantity_delta, trim(p_reason),
    trim(p_idempotency_key), p_related_transaction_id, coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (user_id, idempotency_key) do nothing
  returning id into v_ledger_id;

  if v_ledger_id is null then
    select * into v_existing
    from public.wallet_ledger
    where user_id = p_user_id and idempotency_key = trim(p_idempotency_key);

    if v_existing.asset_type <> p_asset_type
      or v_existing.asset_code is distinct from p_asset_code
      or v_existing.quantity_delta <> p_quantity_delta
      or v_existing.reason <> trim(p_reason)
      or v_existing.related_transaction_id is distinct from p_related_transaction_id then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;

    if p_asset_type = 'GOLD' then
      select balance into v_new_balance
      from public.gold_wallets where user_id = p_user_id;
    else
      select quantity into v_new_balance
      from public.tool_inventory
      where user_id = p_user_id and tool_code = p_asset_code;
    end if;

    return jsonb_build_object(
      'duplicate', true,
      'ledgerId', v_existing.id,
      'assetType', v_existing.asset_type,
      'assetCode', v_existing.asset_code,
      'quantityDelta', v_existing.quantity_delta,
      'balance', v_new_balance
    );
  end if;

  if p_asset_type = 'GOLD' then
    update public.gold_wallets
      set balance = balance + p_quantity_delta
      where user_id = p_user_id and balance + p_quantity_delta >= 0
      returning balance into v_new_balance;
  else
    update public.tool_inventory
      set quantity = quantity + p_quantity_delta
      where user_id = p_user_id
        and tool_code = p_asset_code
        and quantity + p_quantity_delta >= 0
      returning quantity into v_new_balance;
  end if;

  if v_new_balance is null then
    raise exception using errcode = '23514', message = 'ASSET_BALANCE_INSUFFICIENT_OR_MISSING';
  end if;

  return jsonb_build_object(
    'duplicate', false,
    'ledgerId', v_ledger_id,
    'assetType', p_asset_type,
    'assetCode', p_asset_code,
    'quantityDelta', p_quantity_delta,
    'balance', v_new_balance
  );
end;
$$;

revoke all on function public.apply_wallet_delta(uuid, text, text, bigint, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.apply_wallet_delta(uuid, text, text, bigint, text, text, text, jsonb)
  to service_role;
