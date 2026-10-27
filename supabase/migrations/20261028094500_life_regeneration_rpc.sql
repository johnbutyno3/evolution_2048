-- Catch up elapsed 40-minute life regeneration periods in one atomic operation.
-- Trusted caller must first confirm that the effective membership is FREE.
create or replace function public.regenerate_lives(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lives integer;
  v_next_regen_at timestamptz;
  v_original_next_regen_at timestamptz;
  v_periods integer;
  v_grant integer;
  v_new_lives integer;
  v_new_next_regen_at timestamptz;
  v_idempotency_key text;
  v_ledger_id uuid;
begin
  if p_user_id is null then
    raise exception using errcode = '22023', message = 'INVALID_USER_ID';
  end if;

  select life_count, next_regen_at
    into v_lives, v_next_regen_at
    from public.life_wallets
    where user_id = p_user_id
    for update;

  if v_lives is null then
    raise exception using errcode = 'P0002', message = 'LIFE_WALLET_NOT_FOUND';
  end if;

  if v_lives >= 5 or v_next_regen_at is null or v_next_regen_at > now() then
    return jsonb_build_object(
      'regenerated', 0,
      'lives', v_lives,
      'nextRegenAt', v_next_regen_at
    );
  end if;

  v_original_next_regen_at := v_next_regen_at;
  v_periods := floor(extract(epoch from (now() - v_next_regen_at)) / 2400)::integer + 1;
  v_grant := least(5 - v_lives, v_periods);
  v_new_lives := v_lives + v_grant;
  v_new_next_regen_at := case
    when v_new_lives >= 5 then null
    else v_next_regen_at + make_interval(mins => v_grant * 40)
  end;
  v_idempotency_key := 'life-regen:' || extract(epoch from v_original_next_regen_at)::bigint::text;

  update public.life_wallets
    set life_count = v_new_lives,
        next_regen_at = v_new_next_regen_at
    where user_id = p_user_id;

  insert into public.life_ledger (
    user_id, quantity_delta, reason, idempotency_key, metadata
  )
  values (
    p_user_id, v_grant, 'REGENERATION', v_idempotency_key,
    jsonb_build_object(
      'previousNextRegenAt', v_original_next_regen_at,
      'periodsElapsed', v_periods
    )
  )
  on conflict (user_id, idempotency_key) do nothing
  returning id into v_ledger_id;

  if v_ledger_id is null then
    -- This should only occur if data was manually altered; fail closed so
    -- the surrounding transaction rolls back the wallet update.
    raise exception using errcode = '23505', message = 'LIFE_REGENERATION_ALREADY_RECORDED';
  end if;

  return jsonb_build_object(
    'regenerated', v_grant,
    'ledgerId', v_ledger_id,
    'lives', v_new_lives,
    'nextRegenAt', v_new_next_regen_at
  );
end;
$$;

revoke all on function public.regenerate_lives(uuid) from public, anon, authenticated;
grant execute on function public.regenerate_lives(uuid) to service_role;
