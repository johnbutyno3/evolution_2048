-- Admin-only shop configuration updates are routed through a trusted Edge Function.
create or replace function public.admin_update_shop_products(p_products jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_products is null or jsonb_typeof(p_products) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_SHOP_PRODUCTS';
  end if;

  update public.shop_config
  set products = p_products
  where id = 'global';

  if not found then
    raise exception using errcode = 'P0002', message = 'SHOP_CONFIG_MISSING';
  end if;
end;
$$;

revoke all on function public.admin_update_shop_products(jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_update_shop_products(jsonb) to service_role;
