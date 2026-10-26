-- OWNER ONLY: paste into Supabase SQL Editor, never into Flutter or an Edge Function.
-- Fictional order for the school demo. No Xendit call, charge, or actual payment evidence.
-- Replace ONLY the customer UUID below with the intended Authentication > Users UID.
-- Requires the existing ecommerce migrations (0001-0003 at minimum).
begin;
do $$
declare
  v_customer_id uuid := '00000000-0000-0000-0000-000000000000';
  v_key uuid;
  v_order_id uuid;
  v_existing record;
begin
  if v_customer_id = '00000000-0000-0000-0000-000000000000' then
    raise exception 'Replace v_customer_id with the intended Auth user UID first.';
  end if;
  if to_regclass('public.orders') is null or to_regclass('public.profiles') is null
    or to_regclass('public.order_items') is null or to_regclass('public.payments') is null
    or to_regclass('public.order_payment_summary') is null
    or to_regprocedure('public.admin_update_fulfillment(uuid,text)') is null then
    raise exception 'Ecommerce setup is incomplete. Follow docs/START_HERE.md before seeding a purchase.';
  end if;
  if not exists(select 1 from public.profiles where id=v_customer_id) then
    raise exception 'Customer profile not found. Use an existing Auth UID from this Supabase project.';
  end if;

  v_key := md5('bmc-demo-purchase-v1:' || v_customer_id::text)::uuid;
  perform pg_advisory_xact_lock(hashtextextended('bmc-demo-purchase-v1:' || v_customer_id::text,0));
  select * into v_existing from public.orders where user_id=v_customer_id and idempotency_key=v_key;
  if found then
    if v_existing.request_fingerprint <> 'DEMO_ONLY_NO_CHARGE_V1' then
      raise exception 'Demo key already belongs to another order; no changes made.';
    end if;
    raise notice 'Demo order % already exists. Current statuses are preserved.',v_existing.order_number;
    return;
  end if;

  -- Snapshot-only products: no catalog, saved address, cart, or inventory changes.
  insert into public.orders(user_id,order_number,idempotency_key,request_fingerprint,source,
    payment_status,fulfillment_status,subtotal_minor,shipping_minor,total_minor,
    delivery_address,expires_at,paid_at)
  values(v_customer_id,'DEMO-' || upper(replace(v_customer_id::text,'-','')) || '-001',
    v_key,'DEMO_ONLY_NO_CHARGE_V1','buy_now','paid','preparing',300000,15000,315000,
    jsonb_build_object('recipient','DEMO Customer','phone','09000000000',
      'province','Metro Manila','city','Quezon City','barangay','DEMO Barangay',
      'street','123 Demo Street - fictional address','postal_code','1100',
      'instructions','DEMO ONLY. No actual payment or delivery.'),
    now() + interval '30 minutes',now()) returning id into v_order_id;

  insert into public.order_items(order_id,variant_id,sku,product_name,option_label,unit_price_minor,quantity)
  values
    (v_order_id,null,'DEMO-ONLY-TEE','DEMO - Archive Tee','M',120000,1),
    (v_order_id,null,'DEMO-ONLY-RING','DEMO - Silver Band','US 8',180000,1);

  -- Terminal dummy payment: no payment URL/provider session, so the worker does not poll Xendit.
  -- The non-provider ID below is explicitly fictional; never use this pattern for real purchases.
  insert into public.payments(order_id,reference_id,provider_payment_id,expected_amount_minor,
    currency,state,provider_status,failure_code,expires_at)
  values(v_order_id,'demo_only_' || v_order_id::text,'DEMO-NO-CHARGE-' || v_order_id::text,
    315000,'PHP','paid','DEMO_ONLY_NOT_XENDIT','DEMO_ONLY_NO_CHARGE',now() + interval '30 minutes');
end $$;
commit;

-- Result: one demo row per customer, with PHP amounts for easy dashboard review.
select o.order_number,o.user_id,o.payment_status,o.fulfillment_status,
  o.total_minor / 100.0 as total_php,p.state as payment_state,
  (select count(*) from public.order_items i where i.order_id=o.id) as item_count
from public.orders o join public.payments p on p.order_id=o.id
where o.request_fingerprint='DEMO_ONLY_NO_CHARGE_V1'
order by o.created_at desc;
