-- Settle an unfinished game exactly once when the player leaves or the board reaches Game Over.
-- The caller must replay-validate the supplied log in a trusted Edge Function.
alter table public.game_session_events
  drop constraint if exists game_session_events_event_type_check;
alter table public.game_session_events
  add constraint game_session_events_event_type_check
  check (event_type in ('CHAPTER_COMPLETE', 'SESSION_ABANDON'));

create or replace function public.abandon_game_session(
  p_user_id uuid,
  p_game_id uuid,
  p_event_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.game_sessions%rowtype;
  v_existing_event public.game_session_events%rowtype;
  v_event_row_id uuid;
  v_account_status text;
  v_tier text;
  v_membership_status text;
  v_usage jsonb;
  v_previous_usage jsonb;
  v_tool text;
  v_asset_code text;
  v_total bigint;
  v_settled bigint;
  v_delta bigint;
  v_lives integer;
  v_next_regen_at timestamptz;
  v_result jsonb;
begin
  if p_user_id is null or p_game_id is null or p_event_id is null
    or p_payload is null or pg_catalog.jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_SESSION_ABANDON_REQUEST';
  end if;

  select * into v_session
    from public.game_sessions
    where user_id = p_user_id and game_id = p_game_id
    for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'GAME_SESSION_NOT_FOUND';
  end if;

  select * into v_existing_event
    from public.game_session_events
    where user_id = p_user_id and event_id = p_event_id
    for update;
  if found then
    if v_existing_event.game_id <> p_game_id
      or v_existing_event.event_type <> 'SESSION_ABANDON'
      or v_existing_event.payload is distinct from p_payload then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;
    return coalesce(v_existing_event.result, jsonb_build_object(
      'duplicate', true, 'gameId', p_game_id, 'state', v_session.state
    ));
  end if;

  if v_session.state <> 'ACTIVE' then
    raise exception using errcode = '55000', message = 'GAME_SESSION_NOT_ACTIVE';
  end if;

  select account_status into v_account_status
    from public.profiles where user_id = p_user_id;
  if v_account_status is distinct from 'active' then
    raise exception using errcode = '42501', message = 'ACCOUNT_RESTRICTED';
  end if;

  select tier, status into v_tier, v_membership_status
    from public.memberships where user_id = p_user_id for update;
  if v_tier is null or v_membership_status is null then
    raise exception using errcode = 'P0002', message = 'MEMBERSHIP_NOT_FOUND';
  end if;
  if v_membership_status = 'under_review' then
    raise exception using errcode = '42501', message = 'MEMBERSHIP_REQUIRES_REVIEW';
  end if;

  v_usage := p_payload -> 'toolUsage';
  if v_usage is null or pg_catalog.jsonb_typeof(v_usage) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_VALIDATED_REPLAY_RESULT';
  end if;

  insert into public.game_session_events (user_id, game_id, event_id, event_type, payload)
  values (p_user_id, p_game_id, p_event_id, 'SESSION_ABANDON', p_payload)
  returning id into v_event_row_id;

  v_previous_usage := coalesce(v_session.tool_usage, '{}'::jsonb);
  for v_tool in select unnest(array['revive', 'timeRewind', 'positionSwap', 'duplicate'])
  loop
    v_total := coalesce((v_usage ->> v_tool)::bigint, 0);
    v_settled := coalesce((v_previous_usage ->> v_tool)::bigint, 0);
    if v_total < 0 or v_settled < 0 or v_total < v_settled then
      raise exception using errcode = '23514', message = 'TOOL_USAGE_REPLAY_CONFLICT';
    end if;
    v_delta := v_total - v_settled;

    if v_tool = 'revive' then v_asset_code := 'REMOVE';
    elsif v_tool = 'timeRewind' then v_asset_code := 'UNDO';
    elsif v_tool = 'positionSwap' then v_asset_code := 'SWAP';
    else v_asset_code := 'DUPLICATE';
    end if;

    if v_delta = 0 or
      (v_tier = 'GOLDEN' and v_membership_status = 'active' and v_tool = 'timeRewind') then
      continue;
    end if;

    perform public.apply_wallet_delta(
      p_user_id, 'TOOL', v_asset_code, -v_delta, 'GAME_TOOL_USAGE',
      'game-tool-abandon:' || p_game_id::text || ':' || p_event_id::text || ':' || v_asset_code,
      null, jsonb_build_object('gameId', p_game_id, 'eventId', p_event_id)
    );
  end loop;

  -- Leaving or Game Over never refunds the Life already charged at game start.
  select life_count, next_regen_at into v_lives, v_next_regen_at
    from public.life_wallets where user_id = p_user_id;

  update public.game_sessions
    set state = 'ABANDONED',
        end_reason = case
          when p_payload ->> 'reason' = 'GAME_OVER' then 'GAME_OVER'
          else 'PLAYER_ABANDONED'
        end,
        tool_usage = v_usage,
        final_score = coalesce((p_payload ->> 'score')::bigint, 0),
        final_highest_value = coalesce((p_payload ->> 'highestValue')::bigint, 0),
        event_sequence = event_sequence + 1
    where user_id = p_user_id and game_id = p_game_id
    returning * into v_session;

  v_result := jsonb_build_object(
    'duplicate', false, 'gameId', p_game_id, 'state', v_session.state,
    'endReason', v_session.end_reason, 'lives', v_lives,
    'nextRegenAt', v_next_regen_at
  );
  update public.game_session_events set result = v_result where id = v_event_row_id;
  return v_result;
end;
$$;

revoke all on function public.abandon_game_session(uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.abandon_game_session(uuid, uuid, uuid, jsonb)
  to service_role;
