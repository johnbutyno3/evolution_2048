-- Start a game session atomically with FREE life debit and idempotency.
-- This function is service-role-only and must only be invoked after an authenticated
-- Edge Function has validated the request body.
create or replace function public.start_game_session(
  p_user_id uuid,
  p_request_id uuid,
  p_game_id uuid,
  p_chapter_code text,
  p_previous_game_id uuid default null,
  p_initial_tiles jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account_status text;
  v_tier text;
  v_membership_status text;
  v_existing public.game_sessions%rowtype;
  v_previous public.game_sessions%rowtype;
  v_active public.game_sessions%rowtype;
  v_lives integer;
  v_next_regen_at timestamptz;
  v_life_result jsonb;
  v_session public.game_sessions%rowtype;
  v_unlimited boolean;
  v_tile jsonb;
  v_nonempty_tiles integer := 0;
begin
  if p_user_id is null or p_request_id is null or p_game_id is null
    or p_chapter_code not in ('C1', 'C2', 'C3', 'C4', 'C5', 'C6')
    or p_game_id = p_previous_game_id
    or p_initial_tiles is null
    or pg_catalog.jsonb_typeof(p_initial_tiles) <> 'array'
    or pg_catalog.jsonb_array_length(p_initial_tiles) <> 16 then
    raise exception using errcode = '22023', message = 'INVALID_GAME_SESSION_REQUEST';
  end if;

  for v_tile in
    select value from pg_catalog.jsonb_array_elements(p_initial_tiles) as tiles(value)
  loop
    if v_tile = 'null'::jsonb then
      continue;
    elsif v_tile <> '2'::jsonb and v_tile <> '4'::jsonb then
      raise exception using errcode = '22023', message = 'INVALID_INITIAL_TILES';
    end if;
    v_nonempty_tiles := v_nonempty_tiles + 1;
  end loop;

  if v_nonempty_tiles <> 2 then
    raise exception using errcode = '22023', message = 'INVALID_INITIAL_TILES';
  end if;

  -- Serialize session starts per user to prevent concurrent new-game races.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

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

  -- A retried request returns its existing session and never charges twice.
  select * into v_existing
    from public.game_sessions
    where user_id = p_user_id and request_id = p_request_id;
  if found then
    if v_existing.game_id <> p_game_id
      or v_existing.chapter_code <> p_chapter_code
      or v_existing.initial_tiles is distinct from p_initial_tiles then
      raise exception using errcode = '23505', message = 'REQUEST_ID_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;
    select life_count, next_regen_at into v_lives, v_next_regen_at
      from public.life_wallets where user_id = p_user_id;
    return jsonb_build_object(
      'duplicate', true,
      'gameId', v_existing.game_id,
      'requestId', v_existing.request_id,
      'chapterCode', v_existing.chapter_code,
      'state', v_existing.state,
      'eventSequence', v_existing.event_sequence,
      'lives', v_lives,
      'nextRegenAt', v_next_regen_at,
      'unlimitedLives', v_membership_status = 'active' and v_tier in ('PREMIUM', 'GOLDEN')
    );
  end if;

  if p_previous_game_id is not null then
    select * into v_previous
      from public.game_sessions
      where user_id = p_user_id and game_id = p_previous_game_id
      for update;
    if not found then
      raise exception using errcode = 'P0002', message = 'PREVIOUS_SESSION_NOT_FOUND';
    end if;
    if v_previous.state = 'ACTIVE' then
      update public.game_sessions
        set state = 'ABANDONED', end_reason = 'PLAYER_ABANDONED'
        where game_id = p_previous_game_id and user_id = p_user_id;
    end if;

    select * into v_active
      from public.game_sessions
      where user_id = p_user_id
        and state = 'ACTIVE'
        and game_id <> p_previous_game_id
      order by updated_at desc
      limit 1
      for update;
    if found then
      raise exception using errcode = '23505', message = 'ACTIVE_SESSION_EXISTS';
    end if;
  else
    select * into v_active
      from public.game_sessions
      where user_id = p_user_id and state = 'ACTIVE'
      order by updated_at desc
      limit 1
      for update;
    if found then
      raise exception using errcode = '23505', message = 'ACTIVE_SESSION_EXISTS';
    end if;
  end if;

  v_unlimited := v_membership_status = 'active' and v_tier in ('PREMIUM', 'GOLDEN');
  if not v_unlimited then
    v_life_result := public.apply_life_delta(
      p_user_id,
      -1,
      'NEW_GAME_DEBIT',
      p_game_id,
      'new-game:' || p_request_id::text,
      jsonb_build_object('requestId', p_request_id, 'chapterCode', p_chapter_code)
    );
    v_lives := (v_life_result ->> 'lives')::integer;
    v_next_regen_at := (v_life_result ->> 'nextRegenAt')::timestamptz;
  else
    select life_count, next_regen_at into v_lives, v_next_regen_at
      from public.life_wallets where user_id = p_user_id;
  end if;

  insert into public.game_sessions (
    game_id, user_id, chapter_code, state, request_id, event_sequence, initial_tiles
  )
  values (
    p_game_id, p_user_id, p_chapter_code, 'ACTIVE', p_request_id, 0, p_initial_tiles
  )
  returning * into v_session;

  return jsonb_build_object(
    'duplicate', false,
    'gameId', v_session.game_id,
    'requestId', v_session.request_id,
    'chapterCode', v_session.chapter_code,
    'state', v_session.state,
    'eventSequence', v_session.event_sequence,
    'lives', v_lives,
    'nextRegenAt', v_next_regen_at,
    'unlimitedLives', v_unlimited
  );
end;
$$;

revoke all on function public.start_game_session(uuid, uuid, uuid, text, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.start_game_session(uuid, uuid, uuid, text, uuid, jsonb)
  to service_role;
