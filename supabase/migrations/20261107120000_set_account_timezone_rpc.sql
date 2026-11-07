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
begin
  if p_user_id is null or p_timezone is null or length(p_timezone) > 64
     or not exists (
       select 1 from pg_catalog.pg_timezone_names
       where name = p_timezone
     ) then
    raise exception using errcode = '22023', message = 'INVALID_ACCOUNT_TIMEZONE';
  end if;

  update public.profiles
    set timezone_name = p_timezone,
        updated_at = now()
    where user_id = p_user_id;

  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;
end;
$$;

revoke all on function public.set_account_timezone(uuid, text) from public, anon, authenticated;
grant execute on function public.set_account_timezone(uuid, text) to service_role;
