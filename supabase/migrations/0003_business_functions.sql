begin;
create function private.checkout_data(p_order uuid) returns jsonb language sql security definer set search_path = '' as $$
  select jsonb_build_object('order',to_jsonb(o),'payment',to_jsonb(p),'items',
    (select coalesce(jsonb_agg(to_jsonb(i) order by i.id),'[]'::jsonb) from public.order_items i where i.order_id=o.id))
  from public.orders o join public.payments p on p.order_id=o.id where o.id=p_order;
$$;
create function private.release_holds(p_order uuid) returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select v.id,h.quantity from public.inventory_reservations h join public.product_variants v on v.id=h.variant_id
    where h.order_id=p_order and h.state='held' order by v.id for update of v loop
    update public.product_variants set stock_reserved=stock_reserved-r.quantity where id=r.id;
  end loop;
  update public.inventory_reservations set state='released' where order_id=p_order and state='held';
end $$;

create function public.ecom_create_checkout(p_user uuid,p_address uuid,p_items jsonb,p_source text,p_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a public.addresses; s public.shop_settings; old_order public.orders;
  oid uuid := gen_random_uuid(); fingerprint text; lines jsonb; snapshots jsonb := '[]';
  item record; v record; subtotal bigint := 0; expiry timestamptz;
begin
  if p_user is null or p_key is null or p_source is null or p_source not in ('cart','buy_now')
    or jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 20 then
    raise exception 'Invalid checkout request' using errcode='22023';
  end if;
  fingerprint := encode(sha256(convert_to(jsonb_build_object('address',p_address,'items',p_items,'source',p_source)::text,'UTF8')),'hex');
  perform pg_advisory_xact_lock(hashtextextended(p_user::text||p_key::text,0));
  select * into old_order from public.orders where user_id=p_user and idempotency_key=p_key;
  if found then
    if old_order.request_fingerprint<>fingerprint then raise exception 'Checkout key already used for different items' using errcode='22023'; end if;
    return private.checkout_data(old_order.id);
  end if;
  select * into a from public.addresses where id=p_address and user_id=p_user for share;
  if not found then raise exception 'Choose your own saved address' using errcode='22023'; end if;
  select * into strict s from public.shop_settings where id=true for share;
  if p_source='cart' then
    if (select count(distinct x.cart_item_id) from jsonb_to_recordset(p_items) as x(cart_item_id uuid)) <> jsonb_array_length(p_items) then
      raise exception 'Select distinct cart items' using errcode='22023';
    end if;
    select jsonb_agg(jsonb_build_object('variant_id',c.variant_id,'quantity',c.quantity,'cart_id',c.id,'revision',c.revision) order by c.variant_id)
      into lines from public.cart_items c join jsonb_to_recordset(p_items) as x(cart_item_id uuid) on x.cart_item_id=c.id where c.user_id=p_user;
    if coalesce(jsonb_array_length(lines),0)<>jsonb_array_length(p_items) then raise exception 'Cart item not found' using errcode='22023'; end if;
  else
    if jsonb_array_length(p_items)<>1 then raise exception 'Buy Now requires one variant' using errcode='22023'; end if;
    lines := p_items;
  end if;
  perform 1 from public.product_variants pv join jsonb_to_recordset(lines) as x(variant_id uuid) on x.variant_id=pv.id order by pv.id for update of pv;
  if p_source='cart' then
    -- Always lock variants before cart rows, matching paid-cart cleanup's lock order.
    perform 1 from public.cart_items c join jsonb_to_recordset(lines) as x(cart_id uuid) on x.cart_id=c.id
      where c.user_id=p_user order by c.id for share of c;
    if exists(select 1 from jsonb_to_recordset(lines) as x(cart_id uuid,variant_id uuid,quantity integer,revision bigint)
      left join public.cart_items c on c.id=x.cart_id and c.user_id=p_user
      where c.id is null or c.variant_id<>x.variant_id or c.quantity<>x.quantity or c.revision<>x.revision) then
      raise exception 'Cart changed; review your items before checkout' using errcode='22023';
    end if;
  end if;
  for item in select * from jsonb_to_recordset(lines) as x(variant_id uuid,quantity integer,cart_id uuid,revision bigint) order by variant_id loop
    if item.variant_id is null or item.quantity is null or item.quantity not between 1 and 99 then raise exception 'Invalid item quantity' using errcode='22023'; end if;
    select pv.*,p.name as product_name,
      (select storage_path from public.product_images where product_id=p.id order by sort_order,id limit 1) as image_path
      into v from public.product_variants pv join public.products p on p.id=pv.product_id join public.categories c on c.id=p.category_id
      where pv.id=item.variant_id and pv.is_active and p.is_active and c.is_active;
    if not found then raise exception 'Product is unavailable' using errcode='22023'; end if;
    if v.stock_on_hand-v.stock_reserved<item.quantity then raise exception 'Not enough stock for selected variant' using errcode='22023'; end if;
    subtotal := subtotal + v.price_minor*item.quantity;
    snapshots := snapshots || jsonb_build_array(jsonb_build_object('variant_id',v.id,'sku',v.sku,'product_name',v.product_name,
      'option_label',v.option_label,'image_path',v.image_path,'unit_price_minor',v.price_minor,'quantity',item.quantity,
      'source_cart_id',item.cart_id,'source_cart_revision',item.revision));
  end loop;
  expiry := now()+make_interval(mins=>s.reservation_minutes);
  insert into public.orders(id,user_id,order_number,idempotency_key,request_fingerprint,source,subtotal_minor,shipping_minor,total_minor,delivery_address,expires_at)
    values(oid,p_user,'BMC-'||upper(replace(oid::text,'-','')),p_key,fingerprint,p_source,subtotal,s.shipping_fee_minor,subtotal+s.shipping_fee_minor,
      to_jsonb(a)-'id'-'user_id'-'is_default'-'created_at'-'updated_at',expiry);
  insert into public.order_items(order_id,variant_id,sku,product_name,option_label,image_path,unit_price_minor,quantity,source_cart_id,source_cart_revision)
    select oid,x.* from jsonb_to_recordset(snapshots) as x(variant_id uuid,sku text,product_name text,option_label text,image_path text,unit_price_minor bigint,quantity integer,source_cart_id uuid,source_cart_revision bigint);
  for item in select * from jsonb_to_recordset(lines) as x(variant_id uuid,quantity integer) loop
    update public.product_variants set stock_reserved=stock_reserved+item.quantity where id=item.variant_id;
    insert into public.inventory_reservations(order_id,variant_id,quantity,expires_at) values(oid,item.variant_id,item.quantity,expiry);
  end loop;
  insert into public.payments(order_id,reference_id,expected_amount_minor,currency,expires_at)
    values(oid,'bmc_'||oid::text,subtotal+s.shipping_fee_minor,'PHP',expiry);
  return private.checkout_data(oid);
end $$;

create function public.ecom_claim_creation(p_order uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.payments;
begin
  select * into strict p from public.payments where order_id=p_order for update;
  if p.state<>'reserved' then return jsonb_build_object('claimed',false,'data',private.checkout_data(p_order)); end if;
  if p.expires_at<=now() then
    perform 1 from public.orders where id=p_order for update;
    perform private.release_holds(p_order);
    update public.payments set state='creation_failed',failure_code='CHECKOUT_EXPIRED' where id=p.id;
    update public.orders set payment_status='expired' where id=p_order;
    return jsonb_build_object('claimed',false,'data',private.checkout_data(p_order));
  end if;
  update public.payments set state='creating',claim_token=gen_random_uuid() where id=p.id;
  return jsonb_build_object('claimed',true,'data',private.checkout_data(p_order));
end $$;

create function public.ecom_creation_failed(p_order uuid,p_claim uuid,p_definitive boolean,p_code text)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.payments;
begin
  select * into strict p from public.payments where order_id=p_order for update;
  if p.claim_token is distinct from p_claim or p.state not in ('creating','unknown') or p.provider_id is not null then return; end if;
  if p_definitive then
    perform 1 from public.orders where id=p_order for update;
    perform private.release_holds(p_order);
    update public.orders set payment_status='cancelled' where id=p_order;
  end if;
  update public.payments set state=case when p_definitive then 'creation_failed' else 'unknown' end,
    failure_code=left(p_code,100) where id=p.id;
end $$;

-- Input is a normalized provider response fetched by our trusted Edge code, not a client payload.
create function public.ecom_apply_session(p_session jsonb) returns jsonb language plpgsql security definer set search_path = '' as $$
declare p public.payments; o public.orders; r record; sid text := p_session->>'id';
  status text := p_session->>'status'; captured boolean := coalesce((p_session->>'payment_succeeded')::boolean,false);
  expiry timestamptz; review boolean := false;
begin
  select * into p from public.payments where reference_id=p_session->>'reference_id' for update;
  if not found then return jsonb_build_object('ignored',true); end if;
  select * into strict o from public.orders where id=p.order_id for update;
  if sid is null or (p.provider_id is not null and p.provider_id<>sid)
    or (p.provider_business_id is not null and p.provider_business_id is distinct from p_session->>'business_id')
    or p_session->>'session_type' is distinct from 'PAY' or p_session->>'mode' is distinct from 'PAYMENT_LINK'
    or p_session->>'capture_method' is distinct from 'AUTOMATIC'
    or p_session->>'currency' is distinct from p.currency or p_session->>'country' is distinct from 'PH'
    or (p_session->>'amount_minor')::bigint is distinct from p.expected_amount_minor then
    if p.state<>'paid' then
      update public.payments set state='needs_review',failure_code='PROVIDER_MISMATCH' where id=p.id;
      update public.orders set payment_status='needs_review' where id=o.id;
    end if;
    return jsonb_build_object('review',true);
  end if;
  if p.state='paid' then return jsonb_build_object('paid',true,'duplicate',true); end if;
  expiry := coalesce((p_session->>'expires_at')::timestamptz,p.expires_at);
  update public.payments set provider_id=sid,provider_business_id=p_session->>'business_id',provider_status=status,
    payment_url=coalesce(p_session->>'url',payment_url),expires_at=expiry,last_checked_at=now() where id=p.id;
  update public.orders set expires_at=expiry where id=o.id;
  update public.inventory_reservations set expires_at=expiry where order_id=o.id and state='held';
  if status='COMPLETED' and captured then
    if p.state in ('expired','cancelled','creation_failed','needs_review') or not exists(select 1 from public.inventory_reservations where order_id=o.id and state='held') then
      review := true;
    else
      for r in select v.id,h.quantity from public.inventory_reservations h join public.product_variants v on v.id=h.variant_id
        where h.order_id=o.id and h.state='held' order by v.id for update of v loop
        update public.product_variants set stock_on_hand=stock_on_hand-r.quantity,stock_reserved=stock_reserved-r.quantity where id=r.id;
      end loop;
      update public.inventory_reservations set state='committed' where order_id=o.id and state='held';
      update public.payments set state='paid',provider_payment_id=p_session->>'payment_id',failure_code=null where id=p.id;
      update public.orders set payment_status='paid',fulfillment_status='preparing',paid_at=now() where id=o.id;
      if o.source='cart' then
        delete from public.cart_items c using public.order_items i where i.order_id=o.id and c.id=i.source_cart_id
          and c.user_id=o.user_id and c.variant_id=i.variant_id and c.quantity=i.quantity and c.revision=i.source_cart_revision;
      end if;
    end if;
  elsif status in ('EXPIRED','CANCELED') then
    -- A provider lookup, not the local clock, confirmed nonpayable status.
    if p.state='needs_review' then return jsonb_build_object('review',true); end if;
    perform private.release_holds(o.id);
    update public.payments set state=case when status='EXPIRED' then 'expired' else 'cancelled' end where id=p.id;
    update public.orders set payment_status=case when status='EXPIRED' then 'expired' else 'cancelled' end where id=o.id;
  elsif p.state in ('expired','cancelled','creation_failed','needs_review') then
    review := true;
  else
    update public.payments set state=case when status='ACTIVE' then 'active' else 'unknown' end where id=p.id;
  end if;
  if review then
    update public.payments set state='needs_review',failure_code='PAYMENT_RECONCILIATION_REQUIRED' where id=p.id;
    update public.orders set payment_status='needs_review' where id=o.id;
  end if;
  return jsonb_build_object('review',review,'data',private.checkout_data(o.id));
end $$;

create function public.ecom_record_event(p_type text,p_provider text) returns jsonb language plpgsql security definer set search_path = '' as $$
declare e public.webhook_events;
begin
  insert into public.webhook_events(dedupe_key,event_type,provider_id) values(p_type||':'||p_provider,p_type,p_provider)
    on conflict(dedupe_key) do update set attempts=public.webhook_events.attempts+1 returning * into e;
  return to_jsonb(e);
end $$;
create function public.ecom_finish_event(p_event uuid,p_state text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_state not in ('processed','ignored','needs_review') then raise exception 'Invalid event state'; end if;
  update public.webhook_events set state=p_state,processed_at=now(),payment_id=(select id from public.payments p where p.provider_id=public.webhook_events.provider_id)
    where id=p_event;
end $$;
create function public.ecom_reconcile_candidates() returns jsonb language plpgsql security definer set search_path = '' as $$
declare p record;
begin
  -- Only an unclaimed reservation is safe to expire without a provider lookup.
  for p in select order_id from public.payments where state='reserved' and expires_at<=now() order by id limit 20 loop
    perform public.ecom_claim_creation(p.order_id);
  end loop;
  update public.payments set state='unknown',failure_code='CREATION_RESPONSE_MISSING'
    where state='creating' and updated_at<now()-interval '2 minutes';
  return jsonb_build_object(
    'sessions',(select coalesce(jsonb_agg(provider_id),'[]'::jsonb) from
      (select provider_id from public.payments where provider_id is not null and state in ('active','unknown','creating') order by last_checked_at nulls first,id limit 20) q),
    'events',(select coalesce(jsonb_agg(to_jsonb(e)),'[]'::jsonb) from
      (select id,provider_id from public.webhook_events where state='pending' order by created_at limit 20) e),
    'unresolved',(select coalesce(jsonb_agg(to_jsonb(u)),'[]'::jsonb) from
      (select order_id,reference_id,state from public.payments where provider_id is null and state='unknown' order by created_at limit 20) u));
end $$;

create function public.set_default_address(p_address uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.profiles where id=(select auth.uid()) for update;
  if not found or not exists(select 1 from public.addresses where id=p_address and user_id=(select auth.uid())) then raise exception 'Address not found' using errcode='42501'; end if;
  update public.addresses set is_default=false where user_id=(select auth.uid()) and is_default;
  update public.addresses set is_default=true where id=p_address and user_id=(select auth.uid());
end $$;
create function public.admin_variants() returns setof public.product_variants language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise exception 'Admin required' using errcode='42501'; end if;
  return query select * from public.product_variants order by product_id,sku;
end $$;
create function public.admin_save_variant(p_id uuid,p_product uuid,p_sku text,p_option text,p_price bigint,p_stock integer,p_active boolean)
returns uuid language plpgsql security definer set search_path = '' as $$
declare vid uuid := coalesce(p_id,gen_random_uuid());
begin
  if not private.is_admin() then raise exception 'Admin required' using errcode='42501'; end if;
  if p_id is null then
    insert into public.product_variants(id,product_id,sku,option_label,price_minor,stock_on_hand,is_active)
      values(vid,p_product,p_sku,p_option,p_price,p_stock,p_active);
  else
    perform 1 from public.product_variants where id=p_id for update;
    if not found then raise exception 'Variant not found'; end if;
    update public.product_variants set sku=p_sku,option_label=p_option,price_minor=p_price,stock_on_hand=p_stock,is_active=p_active
      where id=p_id and product_id=p_product;
    if not found then raise exception 'Variant product cannot be reassigned'; end if;
  end if;
  return vid;
end $$;
create function public.admin_update_fulfillment(p_order uuid,p_status text) returns void language plpgsql security definer set search_path = '' as $$
declare o public.orders;
begin
  if not private.is_admin() then raise exception 'Admin required' using errcode='42501'; end if;
  select * into strict o from public.orders where id=p_order for update;
  if o.payment_status<>'paid' then raise exception 'Only paid orders can be fulfilled'; end if;
  if p_status=o.fulfillment_status then return; end if;
  if not ((o.fulfillment_status='preparing' and p_status='shipped') or (o.fulfillment_status='shipped' and p_status='delivered')) then
    raise exception 'Invalid fulfillment transition' using errcode='22023';
  end if;
  update public.orders set fulfillment_status=p_status where id=p_order;
end $$;

revoke all on function private.checkout_data(uuid),private.release_holds(uuid),private.touch_row() from public;
do $$ declare f record; begin
  for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname like 'ecom\_%' escape '\' loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
    execute format('grant execute on function %s to service_role',f.signature);
  end loop;
end $$;
revoke all on function public.set_default_address(uuid),public.admin_variants(),public.admin_save_variant(uuid,uuid,text,text,bigint,integer,boolean),public.admin_update_fulfillment(uuid,text) from public,anon;
grant execute on function public.set_default_address(uuid),public.admin_variants(),public.admin_save_variant(uuid,uuid,text,text,bigint,integer,boolean),public.admin_update_fulfillment(uuid,text) to authenticated;
commit;
