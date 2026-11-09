-- Reject a reused restart request ID before settling any different prior session.
-- The request row and SESSION_ABANDON event are committed in the same transaction;
-- both must match the retried payload before the idempotent result can be returned.
create or replace function public.restart_game_session(
  p_user_id uuid,
  p_request_id uuid,
  p_game_id uuid,
  p_chapter_code text,
  p_previous_game_id uuid,
  p_initial_tiles jsonb,
  p_abandon_event_id uuid,
  p_abandon_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.game_sessions%rowtype;
  v_existing_event public.game_session_events%rowtype;
  v_abandon_result jsonb;
  v_start_result jsonb;
begin
  if p_user_id is null or p_request_id is null or p_game_id is null
    or p_previous_game_id is null or p_abandon_event_id is null
    or p_game_id = p_previous_game_id
    or p_chapter_code not in ('C1', 'C2', 'C3', 'C4', 'C5', 'C6')
    or p_initial_tiles is null
    or pg_catalog.jsonb_typeof(p_initial_tiles) <> 'array'
    or pg_catalog.jsonb_array_length(p_initial_tiles) <> 16
    or p_abandon_payload is null
    or pg_catalog.jsonb_typeof(p_abandon_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_RESTART_REQUEST';
  end if;

  -- Match the start_game_session lock order and serialize every operation
  -- that can change the user's active-session pointer.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  -- If this request already created a replacement, prove that the exact same
  -- old session and abandon event are being retried before touching anything.
  select * into v_existing
    from public.game_sessions
    where user_id = p_user_id and request_id = p_request_id
    for update;
  if found then
    if v_existing.game_id <> p_game_id
      or v_existing.chapter_code <> p_chapter_code
      or v_existing.initial_tiles is distinct from p_initial_tiles then
      raise exception using errcode = '23505',
        message = 'REQUEST_ID_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;

    select * into v_existing_event
      from public.game_session_events
      where user_id = p_user_id and event_id = p_abandon_event_id
      for update;
    if not found
      or v_existing_event.game_id <> p_previous_game_id
      or v_existing_event.event_type <> 'SESSION_ABANDON'
      or v_existing_event.payload is distinct from p_abandon_payload then
      raise exception using errcode = '23505',
        message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;
  else
    -- An existing abandon event without its matching replacement request
    -- means this event ID is being reused with a different request ID. Do not
    -- allow a second no-Life-debit replacement from an already-settled session.
    select * into v_existing_event
      from public.game_session_events
      where user_id = p_user_id and event_id = p_abandon_event_id
      for update;
    if found then
      raise exception using errcode = '23505',
        message = 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
    end if;
  end if;

  v_abandon_result := public.abandon_game_session(
    p_user_id,
    p_previous_game_id,
    p_abandon_event_id,
    p_abandon_payload
  );

  -- Restart preserves the Life already charged for the active game.
  v_start_result := public.start_game_session(
    p_user_id,
    p_request_id,
    p_game_id,
    p_chapter_code,
    p_previous_game_id,
    p_initial_tiles,
    false
  );

  return pg_catalog.jsonb_build_object(
    'abandoned', v_abandon_result,
    'started', v_start_result
  );
end;
$$;

revoke all on function public.restart_game_session(uuid, uuid, uuid, text, uuid, jsonb, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.restart_game_session(uuid, uuid, uuid, text, uuid, jsonb, uuid, jsonb)
  to service_role;
