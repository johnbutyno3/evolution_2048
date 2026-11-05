create table if not exists public.creature_collection (
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_code text not null check (chapter_code in ('C1','C2','C3','C4','C5','C6')),
  creature_value bigint not null check (
    creature_value between 2 and 131072
    and (creature_value & (creature_value - 1)) = 0
  ),
  discovered_at timestamptz not null default now(),
  primary key (user_id, chapter_code, creature_value)
);

alter table public.creature_collection enable row level security;
create policy creature_collection_select_own on public.creature_collection
  for select to authenticated using (user_id = (select auth.uid()));

revoke insert, update, delete on public.creature_collection from anon, authenticated;
grant select on public.creature_collection to authenticated;
