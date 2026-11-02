-- Prevent any server path from silently abandoning an ACTIVE session.
-- A session must first record a replay-validated SESSION_ABANDON event in the
-- same transaction (the abandon_game_session RPC does this before its UPDATE).
create or replace function public.require_session_abandon_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.state = 'ACTIVE' and new.state = 'ABANDONED' then
    if not exists (
      select 1
      from public.game_session_events e
      where e.user_id = old.user_id
        and e.game_id = old.game_id
        and e.event_type = 'SESSION_ABANDON'
    ) then
      raise exception using
        errcode = '23514',
        message = 'SESSION_ABANDON_REQUIRES_VALIDATED_SETTLEMENT';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists game_sessions_require_abandon_event
  on public.game_sessions;
create trigger game_sessions_require_abandon_event
  before update of state on public.game_sessions
  for each row
  execute function public.require_session_abandon_event();
