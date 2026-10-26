-- Read-only checks after migrations and seed. One result set for the dashboard.
-- No credentials are returned. Expected counts refer to the unmodified demo seed.
with expected_tables(tablename) as (
  values ('profiles'),('user_roles'),('categories'),('products'),('product_images'),
    ('product_variants'),('addresses'),('cart_items'),('shop_settings'),('orders'),
    ('order_items'),('payments'),('inventory_reservations'),('webhook_events')
), actual_tables as (
  select p.tablename,p.rowsecurity from pg_tables p
  join expected_tables e on e.tablename=p.tablename where p.schemaname='public'
), checks as (
  select 1 as position,'Ecommerce tables' as check_name,14::bigint as expected,
    (select count(*) from actual_tables) as actual
  union all select 2,'Tables with RLS enabled',14,
    (select count(*) from actual_tables where rowsecurity)
  union all select 3,'Demo products',3,(select count(*) from public.products)
  union all select 4,'Demo variants',7,(select count(*) from public.catalog_variants)
  union all select 5,'Product image bucket and limits',1,
    (select count(*) from storage.buckets where id='product-images' and public
      and file_size_limit=5242880
      and allowed_mime_types @> array['image/jpeg','image/png','image/webp']::text[])
  union all select 6,'PHP / PH shop settings',1,
    (select count(*) from public.shop_settings where id=true and currency='PHP' and country='PH')
)
select check_name,expected,actual,
  case when actual=expected then 'OK' else 'CHECK' end as status
from checks order by position;
