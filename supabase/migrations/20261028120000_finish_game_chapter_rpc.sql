create table if not exists public.game_session_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  game_id uuid not null references public.game_sessions(game_id) on delete cascade,
  event_id uuid not null,
  event_type text not null check (event_type in ('CHAPTER_COMPLETE')),
  payload jsonb not null,
  result jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, event_id)
);
create index if not exists game_session_events_game_created_idx
  on public.game_session_events (game_id, created_at desc);
alter table public.game_session_events enable row level security;
create policy game_session_events_select_own on public.game_session_events
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.finish_game_chapter(
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
  v_event_id uuid;
  v_account_status text;
  v_tier text;
  v_membership_status text;
  v_chapter_index integer;
  v_stage_count integer;
  v_target bigint;
  v_score bigint;
  v_highest bigint;
  v_event_count integer;
  v_tool_penalty bigint;
  v_usage jsonb;
  v_previous_usage jsonb;
  v_replay_tool text;
  v_asset_code text;
  v_total bigint;
  v_settled bigint;
  v_delta bigint;
  v_inventory bigint;
  v_life_debit_exists boolean;
  v_life_result jsonb;
  v_lives integer;
  v_next_regen_at timestamptz;
  v_result jsonb;
begin
  if p_user_id is null or p_game_id is null or p_event_id is null
    or p_payload is null or pg_catalog.jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_CHAPTER_COMPLETE_REQUEST';
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
      or v_existing_event.event_type <> 'CHAPTER_COMPLETE'
      or v_existing_event.payload is distinct from p_payload then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;
    return coalesce(v_existing_event.result, jsonb_build_object(
      'duplicate', true, 'gameId', p_game_id, 'state', v_session.state
    ));
  end if;

  if v_session.state = 'COMPLETED' and v_session.end_reason = 'CHAPTER_COMPLETE' then
    raise exception using errcode = '55000', message = 'CHAPTER_ALREADY_COMPLETED_WITH_DIFFERENT_EVENT';
  end if;
  if v_session.state <> 'ACTIVE' then
    raise exception using errcode = '55000', message = 'GAME_SESSION_NOT_ACTIVE';
  end if;
  if v_session.initial_tiles is null then
    raise exception using errcode = '23514', message = 'SESSION_INITIAL_BOARD_MISSING';
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

  v_chapter_index := case v_session.chapter_code
    when 'C1' then 0 when 'C2' then 1 when 'C3' then 2
    when 'C4' then 3 when 'C5' then 4 when 'C6' then 5
    else null end;
  v_stage_count := v_chapter_index + 12;
  v_target := pg_catalog.power(2::numeric, v_stage_count)::bigint;
  v_score := (p_payload ->> 'score')::bigint;
  v_highest := (p_payload ->> 'highestValue')::bigint;
  v_event_count := (p_payload ->> 'eventCount')::integer;
  v_tool_penalty := (p_payload ->> 'toolPenaltyTotal')::bigint;
  v_usage := p_payload -> 'toolUsage';

  if v_score < 0 or v_highest < v_target
    or v_event_count < 0 or v_event_count > 5000
    or v_tool_penalty < 0
    or v_usage is null or pg_catalog.jsonb_typeof(v_usage) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_VALIDATED_REPLAY_RESULT';
  end if;

  insert into public.game_session_events (user_id, game_id, event_id, event_type, payload)
  values (p_user_id, p_game_id, p_event_id, 'CHAPTER_COMPLETE', p_payload)
  returning id into v_event_id;

  v_previous_usage := coalesce(v_session.tool_usage, '{}'::jsonb);
  for v_replay_tool in select unnest(array['revive', 'timeRewind', 'positionSwap', 'duplicate'])
  loop
    v_total := coalesce((v_usage ->> v_replay_tool)::bigint, 0);
    v_settled := coalesce((v_previous_usage ->> v_replay_tool)::bigint, 0);
    if v_total < 0 or v_settled < 0 or v_total < v_settled then
      raise exception using errcode = '23514', message = 'TOOL_USAGE_REPLAY_CONFLICT';
    end if;
    v_delta := v_total - v_settled;

    if v_replay_tool = 'revive' then v_asset_code := 'REMOVE';
    elsif v_replay_tool = 'timeRewind' then v_asset_code := 'UNDO';
    elsif v_replay_tool = 'positionSwap' then v_asset_code := 'SWAP';
    else v_asset_code := 'DUPLICATE';
    end if;

    if v_delta = 0 or (v_tier = 'GOLDEN' and v_membership_status = 'active' and v_replay_tool = 'timeRewind') then
      continue;
    end if;

    perform public.apply_wallet_delta(
      p_user_id,
      'TOOL',
      v_asset_code,
      -v_delta,
      'GAME_TOOL_USAGE',
      'game-tool:' || p_game_id::text || ':' || p_event_id::text || ':' || v_asset_code,
      null,
      jsonb_build_object('gameId', p_game_id, 'eventId', p_event_id)
    );
  end loop;

  insert into public.game_progress (
    user_id, chapter_code, highest_stage, best_score, completed_at, updated_at
  )
  values (
    p_user_id, v_session.chapter_code, v_stage_count, v_score, now(), now()
  )
  on conflict (user_id, chapter_code) do update set
    highest_stage = greatest(public.game_progress.highest_stage, excluded.highest_stage),
    best_score = greatest(public.game_progress.best_score, excluded.best_score),
    completed_at = coalesce(public.game_progress.completed_at, excluded.completed_at),
    updated_at = now();

  select exists (
    select 1 from public.life_ledger
    where user_id = p_user_id and game_id = p_game_id and reason = 'NEW_GAME_DEBIT'
  ) into v_life_debit_exists;

  if v_life_debit_exists and
    (v_membership_status = 'revoked' or (v_membership_status = 'active' and v_tier = 'FREE')) then
    v_life_result := public.apply_life_delta(
      p_user_id, 1, 'CHAPTER_COMPLETE_REFUND', p_game_id,
      'chapter-complete-life:' || p_game_id::text,
      jsonb_build_object('eventId', p_event_id, 'chapterCode', v_session.chapter_code)
    );
    v_lives := (v_life_result ->> 'lives')::integer;
    v_next_regen_at := (v_life_result ->> 'nextRegenAt')::timestamptz;
  else
    select life_count, next_regen_at into v_lives, v_next_regen_at
      from public.life_wallets where user_id = p_user_id;
  end if;

  update public.game_sessions
    set state = 'COMPLETED',
        end_reason = 'CHAPTER_COMPLETE',
        tool_usage = v_usage,
        final_score = v_score,
        final_highest_value = v_highest,
        event_sequence = event_sequence + 1
    where game_id = p_game_id and user_id = p_user_id
    returning * into v_session;

  v_result := jsonb_build_object(
    'duplicate', false,
    'gameId', p_game_id,
    'chapterCode', v_session.chapter_code,
    'state', v_session.state,
    'score', v_score,
    'highestValue', v_highest,
    'highestStage', v_stage_count,
    'lives', v_lives,
    'nextRegenAt', v_next_regen_at
  );

  update public.game_session_events set result = v_result where id = v_event_id;
  return v_result;
end;
$$;

revoke all on function public.finish_game_chapter(uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.finish_game_chapter(uuid, uuid, uuid, jsonb)
  to service_role;
