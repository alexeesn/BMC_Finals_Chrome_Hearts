# Unang gagawin sa Supabase

May local SQL files na tayo. Wala pa akong na-upload sa Supabase account mo. Ang unang activity ay database setup; hiwalay ang Xendit secrets at Edge Function deployment sa later steps.

Kung purchase **records** ang wala sa Table Editor, tingnan muna ang
[dummy purchase at status guide](PURCHASE_RECORDS.md). May check doon para malaman
kung missing tables talaga o empty rows lang; huwag i-rerun ang schema sa existing tables.

## Unang file lang muna

1. Buksan ang intended project mo sa [Supabase Dashboard](https://supabase.com/dashboard). Kung wala pang project, sundan muna ang Step 1 ng [full setup guide](SUPABASE_XENDIT_SETUP.md).
2. Piliin ang **SQL Editor → New Query**.
3. Buksan sa local editor ang [0001_schema.sql](../supabase/migrations/0001_schema.sql).
4. Copy all ng file content, paste sa query, tapos **Run**.
   Kung may choices na Cancel / Run without RLS / Run and enable RLS, piliin ang **Run and enable RLS**. May RLS-enabling loop na rin sa migration; maaaring hindi ito makita ng query preview checker.
5. Kapag successful, makikita sa Table Editor ang 14 ecommerce tables, gaya ng `products`, `addresses`, `cart_items`, at `orders`. Closed muna ang client access; nasa next migration ang intended permissions.

Kung may error, kopyahin ang error text para ma-check bago magpatuloy. Run-once ang migrations. Kung may existing ecommerce tables/data na sa project, kailangan munang i-check ang overlap; walang drop/reset step dito.

## Pagkatapos maging successful

I-run sa magkakahiwalay na queries, in order:

1. [0002_permissions.sql](../supabase/migrations/0002_permissions.sql)
2. [0003_business_functions.sql](../supabase/migrations/0003_business_functions.sql)
3. [0004_storage.sql](../supabase/migrations/0004_storage.sql)
4. [seed.sql](../supabase/seed.sql) — fictional demo products/prices.
5. [verify.sql](../supabase/setup/verify.sql) — read-only checks.

Expected after all steps: 14 listed tables with RLS enabled, 3 demo products, 7 variants, and a `product-images` bucket. Actual product photos are not included yet.

Huwag isama ang `supabase/tests/bootstrap.sql`; pang-local testing lang iyon. Pag okay na ang database, sundan ang full guide para sa admin account, Xendit Test Mode secrets, at the four Edge Functions.
