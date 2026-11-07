-- Persist only valid PostgreSQL IANA time zone names for account-local rewards.
create or replace function public.set_account_timezone(
  p_user_id uuid,
  p_timezone text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current_timezone text;
begin
  if p_user_id is null or p_timezone is null or length(p_timezone) > 64
     or not exists (
       select 1 from pg_catalog.pg_timezone_names
       where name = p_timezone
     ) then
    raise exception using errcode = '22023', message = 'INVALID_ACCOUNT_TIMEZONE';
  end if;

  select timezone_name into v_current_timezone
    from public.profiles
    where user_id = p_user_id
    for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;

  if v_current_timezone is distinct from p_timezone then
    -- Prevent changing device time zones to cross a calendar boundary and
    -- claim multiple daily rewards inside one rolling 24-hour period.
    if exists (
      select 1 from public.daily_gold_claims
      where user_id = p_user_id
        and created_at > now() - interval '24 hours'
    ) then
      return;
    end if;

    update public.profiles
      set timezone_name = p_timezone,
          updated_at = now()
      where user_id = p_user_id;
  end if;
end;
$$;

revoke all on function public.set_account_timezone(uuid, text) from public, anon, authenticated;
grant execute on function public.set_account_timezone(uuid, text) to service_role;
