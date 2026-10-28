create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  game_id uuid references public.game_sessions(game_id) on delete set null,
  severity text not null check (severity in ('low', 'warning', 'high', 'critical')),
  reason text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists security_events_user_created_idx
  on public.security_events (user_id, created_at desc);
alter table public.security_events enable row level security;
create policy security_events_select_admin on public.security_events
  for select to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create or replace function public.lock_account_for_security_violation(
  p_user_id uuid,
  p_game_id uuid,
  p_reason text,
  p_details jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null
    or p_reason not in (
      'forged_replay_detected',
      'tool_usage_replay_conflict',
      'tool_inventory_overuse_detected'
    ) then
    raise exception using errcode = '22023', message = 'INVALID_SECURITY_VIOLATION';
  end if;

  insert into public.security_events (
    user_id, game_id, severity, reason, details
  )
  values (
    p_user_id, p_game_id, 'critical', p_reason,
    coalesce(p_details, '{}'::jsonb)
  );

  update public.profiles
    set account_status = 'locked'
    where user_id = p_user_id;

  return jsonb_build_object(
    'locked', true,
    'supportAvailable', true,
    'reason', p_reason
  );
end;
$$;

revoke all on function public.lock_account_for_security_violation(uuid, uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.lock_account_for_security_violation(uuid, uuid, text, jsonb)
  to service_role;
