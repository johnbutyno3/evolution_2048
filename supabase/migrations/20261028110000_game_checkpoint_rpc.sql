-- Save the latest recoverable board checkpoint without granting permanent progress.
-- Checkpoints are recovery data; chapter completion requires a separate trusted validator.
create or replace function public.save_game_checkpoint(
  p_user_id uuid,
  p_game_id uuid,
  p_event_sequence bigint,
  p_checkpoint jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.game_sessions%rowtype;
begin
  if p_user_id is null or p_game_id is null
    or p_event_sequence is null or p_event_sequence < 1
    or p_checkpoint is null
    or pg_catalog.octet_length(p_checkpoint::text) > 262144 then
    raise exception using errcode = '22023', message = 'INVALID_GAME_CHECKPOINT';
  end if;

  select * into v_session
    from public.game_sessions
    where user_id = p_user_id and game_id = p_game_id
    for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'GAME_SESSION_NOT_FOUND';
  end if;
  if v_session.state <> 'ACTIVE' then
    raise exception using errcode = '55000', message = 'GAME_SESSION_NOT_ACTIVE';
  end if;

  if p_event_sequence < v_session.event_sequence then
    return jsonb_build_object(
      'saved', false,
      'stale', true,
      'eventSequence', v_session.event_sequence,
      'checkpointVersion', v_session.checkpoint_version
    );
  end if;

  if p_event_sequence = v_session.event_sequence then
    if v_session.checkpoint is not distinct from p_checkpoint then
      return jsonb_build_object(
        'saved', false,
        'duplicate', true,
        'eventSequence', v_session.event_sequence,
        'checkpointVersion', v_session.checkpoint_version
      );
    end if;
    raise exception using errcode = '23505', message = 'CHECKPOINT_SEQUENCE_CONFLICT';
  end if;

  update public.game_sessions
    set checkpoint = p_checkpoint,
        event_sequence = p_event_sequence,
        checkpoint_version = checkpoint_version + 1
    where game_id = p_game_id and user_id = p_user_id
    returning * into v_session;

  return jsonb_build_object(
    'saved', true,
    'eventSequence', v_session.event_sequence,
    'checkpointVersion', v_session.checkpoint_version,
    'updatedAt', v_session.updated_at
  );
end;
$$;

revoke all on function public.save_game_checkpoint(uuid, uuid, bigint, jsonb)
  from public, anon, authenticated;
grant execute on function public.save_game_checkpoint(uuid, uuid, bigint, jsonb)
  to service_role;
