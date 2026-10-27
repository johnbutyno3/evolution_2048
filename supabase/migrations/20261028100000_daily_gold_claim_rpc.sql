-- Account time zone is server-owned so clients cannot manipulate daily reward dates.
alter table public.profiles
  add column if not exists timezone_name text not null default 'UTC';

-- Grant daily Gold once per account-local calendar day, atomically with wallet
-- credit. Trusted caller must validate account status before calling.
create or replace function public.claim_daily_gold(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tier text;
  v_membership_status text;
  v_timezone text;
  v_claim_date date;
  v_amount bigint;
  v_claimed boolean;
  v_balance bigint;
  v_ledger jsonb;
begin
  if p_user_id is null then
    raise exception using errcode = '22023', message = 'INVALID_USER_ID';
  end if;

  select tier, status into v_tier, v_membership_status
    from public.memberships
    where user_id = p_user_id
    for update;

  if v_tier is null or v_membership_status is null then
    raise exception using errcode = 'P0002', message = 'MEMBERSHIP_NOT_FOUND';
  end if;

  if v_membership_status <> 'active' or v_tier not in ('PREMIUM', 'GOLDEN') then
    return jsonb_build_object('claimed', false, 'reason', 'NOT_ELIGIBLE');
  end if;

  select timezone_name into v_timezone
    from public.profiles where user_id = p_user_id;

  if v_timezone is null or not exists (
    select 1 from pg_catalog.pg_timezone_names where name = v_timezone
  ) then
    raise exception using errcode = '22023', message = 'INVALID_ACCOUNT_TIMEZONE';
  end if;

  v_claim_date := (now() at time zone v_timezone)::date;
  v_amount := case when v_tier = 'PREMIUM' then 20 else 50 end;

  insert into public.daily_gold_claims (user_id, claim_date, tier, amount, idempotency_key)
  values (
    p_user_id, v_claim_date, v_tier, v_amount,
    'daily-gold:' || v_claim_date::text
  )
  on conflict (user_id, claim_date) do nothing
  returning true into v_claimed;

  if not coalesce(v_claimed, false) then
    select balance into v_balance from public.gold_wallets where user_id = p_user_id;
    return jsonb_build_object(
      'claimed', false,
      'reason', 'ALREADY_CLAIMED',
      'claimDate', v_claim_date,
      'gold', v_balance
    );
  end if;

  v_ledger := public.apply_wallet_delta(
    p_user_id,
    'GOLD',
    null,
    v_amount,
    'DAILY_GOLD',
    'daily-gold:' || v_claim_date::text,
    null,
    jsonb_build_object('claimDate', v_claim_date, 'tier', v_tier)
  );

  return jsonb_build_object(
    'claimed', true,
    'claimDate', v_claim_date,
    'amount', v_amount,
    'gold', (v_ledger ->> 'balance')::bigint
  );
end;
$$;

revoke all on function public.claim_daily_gold(uuid) from public, anon, authenticated;
grant execute on function public.claim_daily_gold(uuid) to service_role;
