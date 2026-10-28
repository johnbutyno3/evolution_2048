-- Add the avatar field consumed by Supabase profile/account services.
-- Keep this additive so it is safe for an already-created project.

alter table public.profiles
  add column if not exists avatar_index integer not null default 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_avatar_index_range'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_avatar_index_range
      check (avatar_index between 0 and 53);
  end if;
end;
$$;

-- The initial schema revoked table-wide UPDATE and granted only display_name
-- and locale_code. Avatar selection is a user-owned cosmetic preference, so
-- explicitly grant only this additional column rather than broadening UPDATE.
grant update (avatar_index) on public.profiles to authenticated;

comment on column public.profiles.avatar_index is
  'User-selected avatar index, constrained to the bundled avatar range 0..53.';
