-- Enforce the product rule: FREE life wallets never exceed five lives.
-- Normalize any pre-existing bonus balances before restoring the hard constraint.
update public.life_wallets
set life_count = least(5, greatest(0, life_count)),
    next_regen_at = case
      when least(5, greatest(0, life_count)) >= 5 then null
      when next_regen_at is null then now() + interval '40 minutes'
      else next_regen_at
    end;

alter table public.life_wallets
  drop constraint if exists life_wallets_life_count_nonnegative;
alter table public.life_wallets
  add constraint life_wallets_life_count_check check (life_count between 0 and 5);

create or replace function public.apply_life_delta(
  p_user_id uuid,
  p_quantity_delta integer,
  p_reason text,
  p_game_id uuid,
  p_idempotency_key text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ledger_id uuid;
  v_existing public.life_ledger%rowtype;
  v_lives integer;
  v_next_regen_at timestamptz;
begin
  if p_user_id is null
    or p_quantity_delta is null
    or p_quantity_delta = 0
    or p_reason not in ('NEW_GAME_DEBIT', 'CHAPTER_COMPLETE_REFUND', 'ADMIN_ADJUSTMENT')
    or p_idempotency_key is null
    or length(trim(p_idempotency_key)) = 0
    or length(p_idempotency_key) > 200 then
    raise exception using errcode = '22023', message = 'INVALID_LIFE_OPERATION';
  end if;

  if p_reason = 'NEW_GAME_DEBIT' and p_quantity_delta <> -1 then
    raise exception using errcode = '22023', message = 'NEW_GAME_MUST_DEBIT_ONE_LIFE';
  end if;
  if p_reason = 'CHAPTER_COMPLETE_REFUND' and p_quantity_delta <> 1 then
    raise exception using errcode = '22023', message = 'CHAPTER_COMPLETE_MUST_REFUND_ONE_LIFE';
  end if;

  insert into public.life_ledger (
    user_id, quantity_delta, reason, game_id, idempotency_key, metadata
  )
  values (
    p_user_id, p_quantity_delta, p_reason, p_game_id,
    trim(p_idempotency_key), coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (user_id, idempotency_key) do nothing
  returning id into v_ledger_id;

  if v_ledger_id is null then
    select * into v_existing
    from public.life_ledger
    where user_id = p_user_id and idempotency_key = trim(p_idempotency_key);

    if v_existing.quantity_delta <> p_quantity_delta
      or v_existing.reason <> p_reason
      or v_existing.game_id is distinct from p_game_id then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;

    select life_count, next_regen_at
      into v_lives, v_next_regen_at
      from public.life_wallets where user_id = p_user_id;

    return jsonb_build_object(
      'duplicate', true,
      'ledgerId', v_existing.id,
      'lives', v_lives,
      'nextRegenAt', v_next_regen_at
    );
  end if;

  if p_reason = 'NEW_GAME_DEBIT' then
    update public.life_wallets
      set life_count = life_count - 1,
          next_regen_at = case
            when life_count = 5 then now() + interval '40 minutes'
            else next_regen_at
          end
      where user_id = p_user_id and life_count > 0
      returning life_count, next_regen_at into v_lives, v_next_regen_at;
  elsif p_reason = 'CHAPTER_COMPLETE_REFUND' then
    -- Chapter-completion refunds never raise the balance above 5.
    update public.life_wallets
      set life_count = least(5, life_count + 1),
          next_regen_at = case
            when life_count + 1 >= 5 then null
            else next_regen_at
          end
      where user_id = p_user_id
      returning life_count, next_regen_at into v_lives, v_next_regen_at;
  else
    -- All FREE life balances are capped at 5, including trusted adjustments.
    update public.life_wallets
      set life_count = least(5, greatest(0, life_count + p_quantity_delta)),
          next_regen_at = case
            when least(5, greatest(0, life_count + p_quantity_delta)) >= 5 then null
            when life_count >= 5 and p_quantity_delta < 0
              then now() + interval '40 minutes'
            else next_regen_at
          end
      where user_id = p_user_id
      returning life_count, next_regen_at into v_lives, v_next_regen_at;
  end if;

  if v_lives is null then
    raise exception using errcode = '23514', message = 'LIFE_BALANCE_INSUFFICIENT_OR_MISSING';
  end if;

  return jsonb_build_object(
    'duplicate', false,
    'ledgerId', v_ledger_id,
    'lives', v_lives,
    'nextRegenAt', v_next_regen_at
  );
end;
$$;


revoke all on function public.apply_life_delta(uuid, integer, text, uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.apply_life_delta(uuid, integer, text, uuid, text, jsonb)
  to service_role;
