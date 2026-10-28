-- Store the player's selected avatar in the authoritative profile.
-- Existing accounts default to avatar 0 and can update only their own avatar.
alter table public.profiles
  add column if not exists avatar_index integer not null default 0
  check (avatar_index between 0 and 53);

grant update (display_name, locale_code, avatar_index)
  on public.profiles to authenticated;
