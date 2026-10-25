-- Read-only checks, after migrations and seed. No credentials are returned.
select tablename,rowsecurity from pg_tables
where schemaname='public' and tablename in
 ('profiles','user_roles','categories','products','product_images','product_variants','addresses','cart_items',
  'shop_settings','orders','order_items','payments','inventory_reservations','webhook_events') order by tablename;
-- Expected with the supplied seed: 3 products and 7 sellable variant records (one has zero available stock).
select count(*) as demo_products from public.products;
select count(*) as demo_variants from public.catalog_variants;
select id,shipping_fee_minor,currency,country,reservation_minutes from public.shop_settings;
select id,name,public,file_size_limit,allowed_mime_types from storage.buckets where id='product-images';
