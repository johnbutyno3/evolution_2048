-- Life regeneration and daily Gold claim state, authoritative on the server.
create table if not exists public.life_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  life_count integer not null default 5 check (life_count between 0 and 5),
  next_regen_at timestamptz,
  updated_at timestamptz not null default now(),
  check (
    (life_count >= 5 and next_regen_at is null)
    or (life_count < 5 and next_regen_at is not null)
  )
);

create table if not exists public.life_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  quantity_delta integer not null check (quantity_delta <> 0),
  reason text not null check (reason in ('NEW_GAME_DEBIT', 'CHAPTER_COMPLETE_REFUND', 'REGENERATION', 'ADMIN_ADJUSTMENT')),
  game_id uuid,
  idempotency_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index if not exists life_ledger_user_created_idx
  on public.life_ledger (user_id, created_at desc);

create table if not exists public.daily_gold_claims (
  user_id uuid not null references auth.users(id) on delete restrict,
  claim_date date not null,
  tier text not null check (tier in ('PREMIUM', 'GOLDEN')),
  amount bigint not null check (amount > 0),
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, claim_date),
  unique (user_id, idempotency_key)
);

alter table public.life_wallets enable row level security;
alter table public.life_ledger enable row level security;
alter table public.daily_gold_claims enable row level security;

create policy life_wallets_select_own on public.life_wallets
  for select to authenticated using (user_id = (select auth.uid()));
create policy life_ledger_select_own on public.life_ledger
  for select to authenticated using (user_id = (select auth.uid()));
create policy daily_gold_claims_select_own on public.daily_gold_claims
  for select to authenticated using (user_id = (select auth.uid()));

drop trigger if exists life_wallets_set_updated_at on public.life_wallets;
create trigger life_wallets_set_updated_at before update on public.life_wallets
for each row execute function public.set_updated_at();

-- Add initial life state to future users. Existing users are backfilled below.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''))
  on conflict (user_id) do nothing;

  insert into public.memberships (user_id) values (new.id)
  on conflict (user_id) do nothing;

  insert into public.gold_wallets (user_id) values (new.id)
  on conflict (user_id) do nothing;

  insert into public.life_wallets (user_id) values (new.id)
  on conflict (user_id) do nothing;

  insert into public.tool_inventory (user_id, tool_code, quantity)
  values (new.id, 'UNDO', 0), (new.id, 'REMOVE', 0),
         (new.id, 'SWAP', 0), (new.id, 'DUPLICATE', 0)
  on conflict (user_id, tool_code) do nothing;

  return new;
end;
$$;

insert into public.life_wallets (user_id)
select id from auth.users
on conflict (user_id) do nothing;
