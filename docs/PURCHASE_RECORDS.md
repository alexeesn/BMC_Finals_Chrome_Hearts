# Dummy purchase records sa Supabase

Para sa Table Editor at sa existing Flutter order/status screens. Local SQL source ito;
ikaw ang magpa-paste sa Supabase dashboard. Walang hosted record na nilikha ng assistant.

## Kung walang tables sa public

Sa tamang Supabase project, SQL Editor → New Query → Run:

```sql
select e.table_name,
  case when t.tablename is null then 'MISSING' else 'EXISTS' end as status
from (values ('orders'),('order_items'),('payments')) as e(table_name)
left join pg_catalog.pg_tables t
  on t.schemaname='public' and t.tablename=e.table_name
order by e.table_name;
```

Kung `EXISTS`, may tables na; maaaring rows ang walang laman. Sa Table Editor,
piliin ang `public`, alisin ang table search/filter, at hanapin ang tatlong pangalan.
Kung `MISSING`, i-check na ito rin ang project URL ng app. Para sa tunay na bagong
database, sundan ang [START_HERE.md](START_HERE.md) at ang
[database setup](SUPABASE_XENDIT_SETUP.md#step-3--ilagay-ang-database-sql).
Kung halo ang `EXISTS`/`MISSING`, ipadala ang result bago mag-run ng migrations.
Run-once ang schema setup; huwag mag-reset o mag-rerun sa existing tables.

## Maglagay ng dummy purchase

Prerequisites: existing ecommerce schema, permissions, business functions, at isang
Auth user na may `profiles` row. Para magamit ang status buttons, kailangan din ng
existing admin account; hindi nagbibigay ng admin role ang seed na ito.

1. Authentication → Users → kopyahin ang UID ng account na gagamit ng **My orders**.
   Puwedeng existing customer o sarili mong admin account kung iyon din ang customer
   view na ite-test. Huwag gumamit ng random UUID.
2. SQL Editor → New Query. Copy/paste ang buong
   [demo-purchase.sql](../supabase/setup/demo-purchase.sql).
3. Sa declaration lang, palitan ang value:

   ```sql
   v_customer_id uuid := '00000000-0000-0000-0000-000000000000';
   ```

   ng kinopyang UID. Iwan ang zero UUID sa validation sa ibaba.
4. Run. Expected: isang `DEMO-…-001` order, payment `paid`, fulfillment `preparing`,
   total **PHP 3,150.00**, at `item_count = 2`.
5. Table Editor → `public` → refresh. May 1 bagong row sa `orders`, 2 sa
   `order_items`, at 1 sa `payments`. Existing records stay as they are.

Sample lang ang **Paid** ng order na ito: walang Xendit session, bayad, o payment URL.
May `DEMO` sa order/product names at `DEMO_ONLY_NOT_XENDIT` sa provider status.
Kasama ito sa admin order/paid counts. Walang binabawas/reserbang stock; snapshot
items lang ito. Walang nadadagdag sa catalog, saved addresses, o cart.
Safe i-run ulit para sa parehong UID: walang duplicate at walang reset ng delivery status.

## Subukan ang status

1. Sa app, admin login → Account → Admin panel → Orders → Paid → buksan ang `DEMO` order.
2. **Mark as shipped** → magiging `shipped` ang `orders.fulfillment_status`.
3. Gamit ang account na UID ang inilagay, Account → My orders → buksan ang parehong
   order → Refresh. Dapat **Shipped** ang Delivery progress.
4. Sa admin, **Mark as delivered**. Refresh muli sa customer → **Delivered**.
5. Sa Table Editor, refresh ang `orders` row para makita ang parehong status.

Gumagamit ito ng existing admin RPC at customer ownership policies. Customer account
cannot change fulfillment; ibang customer cannot read this order. Existing UI refresh
ang gamit; hindi ito Supabase Realtime subscription. Para sa totoong purchases,
verified Xendit processing pa rin ang nagtatakda ng payment status.

Supabase reference: [Tables and data](https://supabase.com/docs/guides/database/tables).
