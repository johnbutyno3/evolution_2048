-- Membership and store transaction rows are server-owned. The client may
-- read its own rows but cannot manufacture, verify, grant, revoke, or rewrite
-- a real-money purchase or membership entitlement.
revoke insert, update, delete on table public.memberships
  from public, anon, authenticated;
revoke insert, update, delete on table public.purchase_transactions
  from public, anon, authenticated;

grant select on table public.memberships, public.purchase_transactions
  to authenticated;
grant all on table public.memberships, public.purchase_transactions
  to service_role;

-- Keep the ownership boundary explicit even when RLS policies are later
-- extended for support or purchase-history presentation.
