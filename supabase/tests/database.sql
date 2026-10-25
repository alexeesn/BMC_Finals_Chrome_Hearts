-- Run against tests/bootstrap.sql + migrations + seed in an isolated local cluster.
\set ON_ERROR_STOP on
begin;
create function pg_temp.expect(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; end $$;
insert into auth.users(id,raw_user_meta_data) values
('a0000000-0000-4000-8000-000000000001','{"role":"admin","display_name":"Customer One"}'),
('a0000000-0000-4000-8000-000000000002','{}'),
('a0000000-0000-4000-8000-000000000003','{}');
update public.user_roles set role='admin' where user_id='a0000000-0000-4000-8000-000000000003';
insert into public.addresses(id,user_id,recipient,phone,province,city,barangay,street,postal_code) values
('b0000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','One','09123456789','Metro Manila','Quezon City','Sample','Original Street','1100'),
('b0000000-0000-4000-8000-000000000002','a0000000-0000-4000-8000-000000000002','Two','09123456789','Metro Manila','Makati','Example','Other Street','1200');
insert into public.cart_items(id,user_id,variant_id,quantity) values
('c0000000-0000-4000-8000-000000000001','a0000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002',1);

set local role authenticated;
set local request.jwt.claim.sub='a0000000-0000-4000-8000-000000000001';
select pg_temp.expect((select count(*)=1 from public.profiles),'profile isolation');
select pg_temp.expect((select role='customer' from public.user_roles),'signup metadata cannot grant admin');
select pg_temp.expect((select count(*)=1 from public.addresses),'address isolation');
select pg_temp.expect((select count(*)=1 from public.cart_items),'own cart read');
select public.set_default_address('b0000000-0000-4000-8000-000000000001');
do $$ begin
  begin update public.user_roles set role='admin'; raise exception 'role grant should fail'; exception when insufficient_privilege then null; end;
  begin insert into public.orders(user_id) values(auth.uid()); raise exception 'order write should fail'; exception when insufficient_privilege then null; end;
  begin perform * from public.product_variants; raise exception 'internal stock read should fail'; exception when insufficient_privilege then null; end;
  begin perform public.ecom_reconcile_candidates(); raise exception 'backend RPC should fail'; exception when insufficient_privilege then null; end;
  begin perform public.admin_variants(); raise exception 'admin RPC should fail'; exception when insufficient_privilege then null; end;
  begin perform public.set_default_address('b0000000-0000-4000-8000-000000000002'); raise exception 'other address should fail'; exception when insufficient_privilege then null; end;
  begin insert into storage.objects(bucket_id,name) values('product-images','forbidden.png'); raise exception 'customer upload should fail'; exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Backend entry points are called with identity established by Edge Auth validation.
set local role service_role;
select public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"variant_id":"30000000-0000-4000-8000-000000000002","quantity":2,"price_minor":1}]','buy_now','d0000000-0000-4000-8000-000000000001')->'order'->>'id' as order_one \gset
select pg_temp.expect((public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"variant_id":"30000000-0000-4000-8000-000000000002","quantity":2,"price_minor":1}]','buy_now','d0000000-0000-4000-8000-000000000001')->'order'->>'id')=:'order_one','checkout idempotency');
do $$ begin
  begin perform public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
    '[{"variant_id":"30000000-0000-4000-8000-000000000002","quantity":1}]','buy_now','d0000000-0000-4000-8000-000000000001');
    raise exception 'changed request should fail'; exception when invalid_parameter_value then null; end;
end $$;
reset role;
select pg_temp.expect((select stock_reserved=2 from public.product_variants where id='30000000-0000-4000-8000-000000000002'),'stock reserved once');
select pg_temp.expect((select total_minor=2415000 from public.orders where id=:'order_one'),'server ignores client price');
select pg_temp.expect((select count(*)=1 from public.payments),'one provider resource per checkout');
update public.addresses set street='New Street' where id='b0000000-0000-4000-8000-000000000001';
select pg_temp.expect((select delivery_address->>'street'='Original Street' from public.orders where id=:'order_one'),'address snapshot');
select public.ecom_claim_creation(:'order_one');
create temporary table verified as select jsonb_build_object('id','ps-aaaaaaaaaaaaaaaaaaaaaaaa','reference_id',reference_id,'business_id','test-business',
 'session_type','PAY','mode','PAYMENT_LINK','capture_method','AUTOMATIC','currency','PHP','country','PH','amount_minor',expected_amount_minor,
 'status','COMPLETED','expires_at',expires_at,'payment_succeeded',true,'payment_id','py-aaaaaaaaaaaaaaaaaaaaaaaa') as session from public.payments where order_id=:'order_one';
select public.ecom_apply_session((select session from verified));
select public.ecom_apply_session((select session from verified));
select public.ecom_apply_session((select session||'{"status":"EXPIRED","payment_succeeded":false}'::jsonb from verified));
select pg_temp.expect((select payment_status='paid' and fulfillment_status='preparing' from public.orders where id=:'order_one'),'paid cannot regress');
select pg_temp.expect((select stock_on_hand=4 and stock_reserved=0 from public.product_variants where id='30000000-0000-4000-8000-000000000002'),'duplicate webhook does not duplicate stock effect');
select pg_temp.expect((select count(*)=1 from public.cart_items),'Buy Now preserves cart');

set local role authenticated;
set local request.jwt.claim.sub='a0000000-0000-4000-8000-000000000002';
select pg_temp.expect((select count(*)=0 from public.orders),'order isolation');
select pg_temp.expect((select count(*)=0 from public.order_items),'order-item isolation');
select pg_temp.expect((select count(*)=0 from public.order_payment_summary),'payment isolation');
set local request.jwt.claim.sub='a0000000-0000-4000-8000-000000000003';
select public.admin_update_fulfillment(:'order_one','shipped');
select public.admin_update_fulfillment(:'order_one','delivered');
do $$ begin
  begin perform public.admin_update_fulfillment((select id from public.orders limit 1),'preparing'); raise exception 'backward fulfillment should fail'; exception when invalid_parameter_value then null; end;
end $$;
insert into storage.objects(bucket_id,name) values('product-images','admin-versioned.png');
reset role;

-- Changed cart rows survive payment cleanup; matching rows are removed.
select public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"cart_item_id":"c0000000-0000-4000-8000-000000000001"}]','cart','d0000000-0000-4000-8000-000000000002')->'order'->>'id' as order_cart \gset
update public.cart_items set quantity=2 where id='c0000000-0000-4000-8000-000000000001';
select public.ecom_apply_session((select session||jsonb_build_object('id','ps-bbbbbbbbbbbbbbbbbbbbbbbb','payment_id','py-bbbbbbbbbbbbbbbbbbbbbbbb','reference_id',p.reference_id,'amount_minor',p.expected_amount_minor) from verified,public.payments p where p.order_id=:'order_cart'));
select pg_temp.expect((select quantity=2 from public.cart_items where id='c0000000-0000-4000-8000-000000000001'),'new cart edits preserved');
select public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"cart_item_id":"c0000000-0000-4000-8000-000000000001"}]','cart','d0000000-0000-4000-8000-000000000003')->'order'->>'id' as order_cleanup \gset
select public.ecom_apply_session((select session||jsonb_build_object('id','ps-cccccccccccccccccccccccc','payment_id','py-cccccccccccccccccccccccc','reference_id',p.reference_id,'amount_minor',p.expected_amount_minor) from verified,public.payments p where p.order_id=:'order_cleanup'));
select pg_temp.expect((select count(*)=0 from public.cart_items),'matching paid cart row removed');

select public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"variant_id":"30000000-0000-4000-8000-000000000005","quantity":1}]','buy_now','d0000000-0000-4000-8000-000000000004')->'order'->>'id' as order_expiry \gset
select public.ecom_apply_session((select session||jsonb_build_object('id','ps-dddddddddddddddddddddddd','status','EXPIRED','payment_succeeded',false,'reference_id',p.reference_id,'amount_minor',p.expected_amount_minor) from verified,public.payments p where p.order_id=:'order_expiry'));
select pg_temp.expect((select stock_on_hand=3 and stock_reserved=0 from public.product_variants where id='30000000-0000-4000-8000-000000000005'),'expiry releases without consuming stock');
select public.ecom_apply_session((select session||jsonb_build_object('id','ps-dddddddddddddddddddddddd','reference_id',p.reference_id,'amount_minor',p.expected_amount_minor) from verified,public.payments p where p.order_id=:'order_expiry'));
select pg_temp.expect((select payment_status='needs_review' from public.orders where id=:'order_expiry'),'late successful payment cannot oversell');

select public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"variant_id":"30000000-0000-4000-8000-000000000005","quantity":1}]','buy_now','d0000000-0000-4000-8000-000000000005')->'order'->>'id' as order_mismatch \gset
select public.ecom_apply_session((select session||jsonb_build_object('id','ps-eeeeeeeeeeeeeeeeeeeeeeee','currency','USD','reference_id',p.reference_id,'amount_minor',p.expected_amount_minor) from verified,public.payments p where p.order_id=:'order_mismatch'));
select pg_temp.expect((select payment_status='needs_review' from public.orders where id=:'order_mismatch'),'wrong currency rejected');
select pg_temp.expect((select stock_reserved=1 from public.product_variants where id='30000000-0000-4000-8000-000000000005'),'mismatched payment does not release hold');
set local role authenticated;
set local request.jwt.claim.sub='a0000000-0000-4000-8000-000000000003';
do $$ begin
  begin perform public.admin_save_variant('30000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000002','DEMO-RING-8','US 8',1800000,0,true);
    raise exception 'stock below reservation should fail'; exception when check_violation then null; end;
end $$;
reset role;
select pg_temp.expect((select is_default from public.addresses where id='b0000000-0000-4000-8000-000000000001'),'default address saved');

-- Durable inbox deduplication and event-to-payment linking.
select public.ecom_record_event('payment_session.completed','ps-aaaaaaaaaaaaaaaaaaaaaaaa')->>'id' as event_id \gset
select pg_temp.expect((public.ecom_record_event('payment_session.completed','ps-aaaaaaaaaaaaaaaaaaaaaaaa')->>'id')=:'event_id','webhook inbox deduplication');
select public.ecom_finish_event(:'event_id','processed');
select pg_temp.expect((select state='processed' and payment_id is not null from public.webhook_events where id=:'event_id'),'webhook inbox linked after processing');

-- Unknown creation does not release inventory; an owner-confirmed rejection does.
select public.ecom_create_checkout('a0000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001',
 '[{"variant_id":"30000000-0000-4000-8000-000000000007","quantity":1}]','buy_now','d0000000-0000-4000-8000-000000000006')->'order'->>'id' as order_unknown \gset
select public.ecom_claim_creation(:'order_unknown')->'data'->'payment'->>'claim_token' as claim_token \gset
select pg_temp.expect((public.ecom_claim_creation(:'order_unknown')->>'claimed')::boolean=false,'provider creation claimed once');
select public.ecom_creation_failed(:'order_unknown',:'claim_token',false,'TEST_TIMEOUT');
select pg_temp.expect((select stock_reserved=1 from public.product_variants where id='30000000-0000-4000-8000-000000000007'),'unknown creation retains inventory');
select pg_temp.expect(jsonb_array_length(public.ecom_reconcile_candidates()->'unresolved')=1,'unknown creation listed for recovery');
select public.ecom_creation_failed(:'order_unknown',:'claim_token',true,'OWNER_CONFIRMED_NO_RESOURCE');
select pg_temp.expect((select stock_reserved=0 from public.product_variants where id='30000000-0000-4000-8000-000000000007'),'definitive failed creation releases inventory');
rollback;
\echo PASS: database security, checkout, stock, payment, snapshots, cart cleanup, and fulfillment checks
