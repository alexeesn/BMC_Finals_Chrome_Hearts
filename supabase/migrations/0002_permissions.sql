begin;
create function private.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.user_roles where user_id = (select auth.uid()) and role = 'admin');
$$;
grant usage on schema private to anon,authenticated,service_role;
revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to anon,authenticated,service_role;

create function private.bootstrap_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id,display_name) values(new.id,left(coalesce(new.raw_user_meta_data->>'display_name',''),120));
  insert into public.user_roles(user_id,role) values(new.id,'customer');
  return new;
end $$;
revoke all on function private.bootstrap_user() from public;
create trigger ecommerce_new_user after insert on auth.users for each row execute function private.bootstrap_user();
insert into public.profiles(id) select id from auth.users on conflict do nothing;
insert into public.user_roles(user_id) select id from auth.users on conflict do nothing;

do $$ declare t text; begin
  foreach t in array array['profiles','user_roles','categories','products','product_images','product_variants','addresses','cart_items','shop_settings','orders','order_items','payments','inventory_reservations','webhook_events'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public, anon, authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;
grant select on public.categories,public.products,public.product_images to anon,authenticated;
grant insert,update on public.categories,public.products,public.product_images to authenticated;
create policy categories_read on public.categories for select to anon,authenticated using(is_active or private.is_admin());
create policy categories_admin on public.categories for all to authenticated using(private.is_admin()) with check(private.is_admin());
create policy products_read on public.products for select to anon,authenticated using(private.is_admin() or (is_active and exists(select 1 from public.categories c where c.id = category_id and c.is_active)));
create policy products_admin on public.products for all to authenticated using(private.is_admin()) with check(private.is_admin());
create policy images_read on public.product_images for select to anon,authenticated using(private.is_admin() or exists(select 1 from public.products p join public.categories c on c.id=p.category_id where p.id=product_id and p.is_active and c.is_active));
create policy images_admin on public.product_images for all to authenticated using(private.is_admin()) with check(private.is_admin());

-- Owner-executed, explicitly filtered view: do not grant direct variant-table reads to clients.
create view public.catalog_variants with (security_barrier = true) as
select v.id,v.product_id,v.sku,v.option_label,v.price_minor,v.stock_on_hand-v.stock_reserved as available_stock
from public.product_variants v join public.products p on p.id=v.product_id join public.categories c on c.id=p.category_id
where v.is_active and p.is_active and c.is_active;
revoke all on public.catalog_variants from public,anon,authenticated;
grant select on public.catalog_variants to anon,authenticated,service_role;

grant select on public.profiles,public.user_roles,public.addresses,public.cart_items,public.orders,public.order_items to authenticated;
grant update(display_name,phone) on public.profiles to authenticated;
create policy profile_own on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy profile_update on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy role_own on public.user_roles for select to authenticated using(user_id=(select auth.uid()));
grant insert(user_id,recipient,phone,province,city,barangay,street,postal_code,instructions) on public.addresses to authenticated;
grant update(recipient,phone,province,city,barangay,street,postal_code,instructions) on public.addresses to authenticated;
grant delete on public.addresses to authenticated;
create policy addresses_own on public.addresses for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
grant insert(user_id,variant_id,quantity) on public.cart_items to authenticated;
grant update(quantity) on public.cart_items to authenticated;
grant delete on public.cart_items to authenticated;
create policy cart_read on public.cart_items for select to authenticated using(user_id=(select auth.uid()));
create policy cart_insert on public.cart_items for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.catalog_variants v where v.id=variant_id));
create policy cart_update on public.cart_items for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy cart_delete on public.cart_items for delete to authenticated using(user_id=(select auth.uid()));
create policy orders_read on public.orders for select to authenticated using(user_id=(select auth.uid()) or private.is_admin());
create policy order_items_read on public.order_items for select to authenticated using(exists(select 1 from public.orders o where o.id=order_id and (o.user_id=(select auth.uid()) or private.is_admin())));

-- Expose safe payment fields only. No direct access to provider claims or failure metadata.
create view public.order_payment_summary with (security_barrier = true) as
select p.order_id,p.state,p.payment_url,p.expires_at,p.updated_at
from public.payments p join public.orders o on o.id=p.order_id
where o.user_id=(select auth.uid()) or private.is_admin();
revoke all on public.order_payment_summary from public,anon,authenticated;
grant select on public.order_payment_summary to authenticated,service_role;
commit;
