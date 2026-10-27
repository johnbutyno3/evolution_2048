create table if not exists public.shop_config (
  id text primary key check (id = 'global'),
  currency text not null default 'USD' check (char_length(currency) = 3),
  products jsonb not null default '{}'::jsonb check (jsonb_typeof(products) = 'object'),
  updated_at timestamptz not null default now()
);

alter table public.shop_config enable row level security;
create policy shop_config_read_public on public.shop_config
  for select to anon, authenticated using (id = 'global');

insert into public.shop_config (id, currency, products)
values (
  'global',
  'USD',
  '{
    "gold_300": {"type":"gold","goldAmount":300,"priceUsd":"0.99","active":true},
    "gold_1000": {"type":"gold","goldAmount":1000,"priceUsd":"2.99","active":true},
    "gold_4000": {"type":"gold","goldAmount":4000,"priceUsd":"9.99","active":true},
    "gold_10000": {"type":"gold","goldAmount":10000,"priceUsd":"19.99","active":true},
    "membership_premium": {"type":"membership","tier":"PREMIUM","priceUsd":"2.99","active":true},
    "membership_golden": {"type":"membership","tier":"GOLDEN","priceUsd":"5.99","active":true},
    "membership_upgrade_golden": {"type":"membership_upgrade","tier":"GOLDEN","priceUsd":"3.00","active":true}
  }'::jsonb
)
on conflict (id) do nothing;

drop trigger if exists shop_config_set_updated_at on public.shop_config;
create trigger shop_config_set_updated_at before update on public.shop_config
for each row execute function public.set_updated_at();
