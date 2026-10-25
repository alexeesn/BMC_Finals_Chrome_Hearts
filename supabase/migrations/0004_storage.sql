begin;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
create policy ecommerce_image_insert on storage.objects for insert to authenticated
with check(bucket_id='product-images' and private.is_admin());
-- Immutable object names preserve past order imagery. Upload a new path instead of overwriting.
-- Deletion/overwrite is owner-only in this first package; do not erase order-linked objects.
commit;
