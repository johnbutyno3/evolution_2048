-- Atomically settle the previous game and create its replacement.
-- If the new game cannot be started (for example, no Life remains), PostgreSQL
-- rolls back the previous settlement too, preserving the old active session.
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
  v_abandon_result jsonb;
  v_start_result jsonb;
begin
  if p_user_id is null or p_previous_game_id is null or p_abandon_event_id is null
    or p_previous_game_id = p_game_id then
    raise exception using errcode = '22023', message = 'INVALID_RESTART_REQUEST';
  end if;

  -- Acquire the same per-user lock as start_game_session before locking the
  -- previous session in abandon_game_session. This preserves one lock order
  -- and serializes restart against concurrent starts without deadlock.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  v_abandon_result := public.abandon_game_session(
    p_user_id,
    p_previous_game_id,
    p_abandon_event_id,
    p_abandon_payload
  );

  v_start_result := public.start_game_session(
    p_user_id,
    p_request_id,
    p_game_id,
    p_chapter_code,
    p_previous_game_id,
    p_initial_tiles
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
