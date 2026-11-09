-- Deduplicate repeated security-review reports for the same user/event/reason.
alter table public.security_events
  add column if not exists idempotency_key text;

update public.security_events
  set idempotency_key = 'legacy:' || id::text
  where idempotency_key is null;

alter table public.security_events
  alter column idempotency_key set not null;

create unique index if not exists security_events_user_idempotency_key_uidx
  on public.security_events (user_id, idempotency_key);
