-- Rebirth 2048 Supabase baseline schema
-- Sensitive account/economy mutations must be performed by trusted Edge Functions
-- using the service role. Never ship the service-role key in Flutter.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 40),
  locale_code text not null default 'en' check (char_length(locale_code) between 2 and 10),
  account_status text not null default 'active' check (account_status in ('active', 'locked', 'under_review')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memberships (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'FREE' check (tier in ('FREE', 'PREMIUM', 'GOLDEN')),
  status text not null default 'active' check (status in ('active', 'revoked', 'under_review')),
  source_transaction_id text,
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.gold_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.tool_inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  tool_code text not null check (tool_code in ('UNDO', 'REMOVE', 'SWAP', 'DUPLICATE')),
  quantity bigint not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, tool_code)
);

create table if not exists public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  asset_type text not null check (asset_type in ('GOLD', 'TOOL', 'LIFE', 'MEMBERSHIP')),
  asset_code text,
  quantity_delta bigint not null check (quantity_delta <> 0),
  reason text not null,
  idempotency_key text not null,
  related_transaction_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);
create index if not exists wallet_ledger_user_created_idx
  on public.wallet_ledger (user_id, created_at desc);

create table if not exists public.game_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_code text not null check (chapter_code in ('C1', 'C2', 'C3', 'C4', 'C5', 'C6')),
  highest_stage integer not null default 0 check (highest_stage >= 0),
  best_score bigint not null default 0 check (best_score >= 0),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, chapter_code)
);

create table if not exists public.game_sessions (
  game_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  chapter_code text not null check (chapter_code in ('C1', 'C2', 'C3', 'C4', 'C5', 'C6')),
  state text not null check (state in ('ACTIVE', 'ABANDONED', 'COMPLETED')),
  end_reason text check (end_reason is null or end_reason in ('GAME_OVER', 'CHAPTER_COMPLETE', 'PLAYER_ABANDONED')),
  request_id uuid not null,
  event_sequence bigint not null default 0 check (event_sequence >= 0),
  checkpoint jsonb,
  checkpoint_version integer not null default 1 check (checkpoint_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, request_id)
);
create index if not exists game_sessions_user_updated_idx
  on public.game_sessions (user_id, updated_at desc);

create table if not exists public.purchase_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  store text not null check (store in ('APPLE_APP_STORE', 'GOOGLE_PLAY')),
  product_id text not null,
  transaction_id text,
  original_transaction_id text,
  status text not null default 'pending'
    check (status in ('pending', 'verified', 'granted', 'rejected', 'refunded', 'revoked', 'under_review')),
  verification_payload_hash text,
  verified_at timestamptz,
  granted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store, transaction_id)
);
create index if not exists purchase_transactions_user_created_idx
  on public.purchase_transactions (user_id, created_at desc);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  category text not null check (category in ('GENERAL', 'PURCHASE', 'REFUND', 'ACCOUNT_APPEAL')),
  subject text not null check (char_length(subject) between 1 and 160),
  status text not null default 'open'
    check (status in ('open', 'waiting_for_player', 'waiting_for_admin', 'resolved', 'closed')),
  related_purchase_id uuid references public.purchase_transactions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists support_tickets_user_created_idx
  on public.support_tickets (user_id, created_at desc);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_user_id uuid references auth.users(id) on delete set null,
  sender_role text not null check (sender_role in ('player', 'admin', 'system')),
  body text not null check (char_length(body) between 1 and 10000),
  created_at timestamptz not null default now()
);
create index if not exists support_messages_ticket_created_idx
  on public.support_messages (ticket_id, created_at);

create table if not exists public.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid references public.support_tickets(id) on delete cascade,
  event_type text not null,
  status text not null default 'pending' check (status in ('pending', 'delivered', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  last_error text,
  created_at timestamptz not null default now(),
  delivered_at timestamptz
);

-- New auth users receive a minimal profile and account wallet records.
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

  insert into public.tool_inventory (user_id, tool_code, quantity)
  values (new.id, 'UNDO', 0), (new.id, 'REMOVE', 0),
         (new.id, 'SWAP', 0), (new.id, 'DUPLICATE', 0)
  on conflict (user_id, tool_code) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Keep updated_at server-generated.
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists memberships_set_updated_at on public.memberships;
create trigger memberships_set_updated_at before update on public.memberships
for each row execute function public.set_updated_at();
drop trigger if exists gold_wallets_set_updated_at on public.gold_wallets;
create trigger gold_wallets_set_updated_at before update on public.gold_wallets
for each row execute function public.set_updated_at();
drop trigger if exists tool_inventory_set_updated_at on public.tool_inventory;
create trigger tool_inventory_set_updated_at before update on public.tool_inventory
for each row execute function public.set_updated_at();
drop trigger if exists game_sessions_set_updated_at on public.game_sessions;
create trigger game_sessions_set_updated_at before update on public.game_sessions
for each row execute function public.set_updated_at();
drop trigger if exists purchase_transactions_set_updated_at on public.purchase_transactions;
create trigger purchase_transactions_set_updated_at before update on public.purchase_transactions
for each row execute function public.set_updated_at();
drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at before update on public.support_tickets
for each row execute function public.set_updated_at();

-- RLS is default-deny for writes to authoritative account/economy tables.
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.gold_wallets enable row level security;
alter table public.tool_inventory enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.game_progress enable row level security;
alter table public.game_sessions enable row level security;
alter table public.purchase_transactions enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table public.admin_notifications enable row level security;

create policy profiles_select_own on public.profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy memberships_select_own on public.memberships
  for select to authenticated using (user_id = (select auth.uid()));
create policy gold_wallets_select_own on public.gold_wallets
  for select to authenticated using (user_id = (select auth.uid()));
create policy tool_inventory_select_own on public.tool_inventory
  for select to authenticated using (user_id = (select auth.uid()));
create policy wallet_ledger_select_own on public.wallet_ledger
  for select to authenticated using (user_id = (select auth.uid()));
create policy game_progress_select_own on public.game_progress
  for select to authenticated using (user_id = (select auth.uid()));
create policy game_sessions_select_own on public.game_sessions
  for select to authenticated using (user_id = (select auth.uid()));
create policy purchase_transactions_select_own on public.purchase_transactions
  for select to authenticated using (user_id = (select auth.uid()));

create policy support_tickets_select_own on public.support_tickets
  for select to authenticated using (user_id = (select auth.uid()));
create policy support_tickets_insert_own on public.support_tickets
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy support_tickets_select_admin on public.support_tickets
  for select to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
create policy support_messages_select_ticket_owner_or_admin on public.support_messages
  for select to authenticated using (
    exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = (select auth.uid())
    )
    or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );
create policy support_messages_insert_player_own_ticket on public.support_messages
  for insert to authenticated with check (
    sender_user_id = (select auth.uid())
    and sender_role = 'player'
    and exists (
      select 1 from public.support_tickets t
      where t.id = ticket_id and t.user_id = (select auth.uid())
    )
  );

create policy admin_notifications_select_admin on public.admin_notifications
  for select to authenticated using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

-- Intentionally no client INSERT/UPDATE/DELETE policies for memberships, wallets,
-- inventory, ledger, game progress/session mutations, purchase verification, or
-- admin notifications. Trusted Edge Functions must enforce ownership, idempotency,
-- transaction verification, and atomic updates for these operations.
