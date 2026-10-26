-- Read-only review before order/payment creation. Apply after migrations 0001–0004.
begin;
create function public.quote_checkout(p_source text,p_address uuid,p_items jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  customer uuid := (select auth.uid()); a public.addresses; s public.shop_settings;
  lines jsonb; item record; variant record; subtotal bigint := 0;
  quoted_items jsonb := '[]'::jsonb;
begin
  if customer is null then raise exception 'Sign in before checkout' using errcode='42501'; end if;
  if p_source is null or p_source not in ('buy_now','cart')
    or jsonb_typeof(p_items) is distinct from 'array' then
    raise exception 'Choose checkout items' using errcode='22023';
  end if;
  if jsonb_array_length(p_items) not between 1 and 20 then
    raise exception 'Choose between 1 and 20 checkout items' using errcode='22023';
  end if;
  select * into a from public.addresses where id=p_address and user_id=customer;
  if not found then raise exception 'Choose your own saved address' using errcode='42501'; end if;
  select * into strict s from public.shop_settings where id=true;
  if p_source='cart' then
    if (select count(distinct x.cart_item_id) from jsonb_to_recordset(p_items) as x(cart_item_id uuid))
      <>jsonb_array_length(p_items) then
      raise exception 'Select distinct cart items' using errcode='22023';
    end if;
    select jsonb_agg(jsonb_build_object('variant_id',c.variant_id,'quantity',c.quantity,
      'cart_item_id',c.id,'cart_revision',c.revision) order by c.id) into lines
      from public.cart_items c join jsonb_to_recordset(p_items) as x(cart_item_id uuid)
        on c.id=x.cart_item_id where c.user_id=customer;
    if coalesce(jsonb_array_length(lines),0)<>jsonb_array_length(p_items) then
      raise exception 'Cart item not found. Refresh your cart' using errcode='22023';
    end if;
  else
    if jsonb_array_length(p_items)<>1 then raise exception 'Buy Now requires one variant' using errcode='22023'; end if;
    lines := p_items;
  end if;
  for item in select * from jsonb_to_recordset(lines)
    as x(variant_id uuid,quantity integer,cart_item_id uuid,cart_revision bigint) loop
    if item.variant_id is null or item.quantity is null or item.quantity not between 1 and 99 then
      raise exception 'Quantity must be between 1 and 99' using errcode='22023';
    end if;
    select v.id,v.sku,v.option_label,v.price_minor,v.stock_on_hand-v.stock_reserved as available_stock,
      p.name as product_name into variant from public.product_variants v
      join public.products p on p.id=v.product_id join public.categories c on c.id=p.category_id
      where v.id=item.variant_id and v.is_active and p.is_active and c.is_active;
    if not found then raise exception 'Product is unavailable. Refresh your selection' using errcode='22023'; end if;
    if variant.available_stock<item.quantity then
      raise exception 'Not enough stock. Refresh your selection' using errcode='22023';
    end if;
    subtotal := subtotal+variant.price_minor*item.quantity;
    quoted_items := quoted_items || jsonb_build_array(jsonb_build_object(
      'variant_id',variant.id,'product_name',variant.product_name,'option_label',variant.option_label,
      'unit_price_minor',variant.price_minor,'quantity',item.quantity,
      'line_total_minor',variant.price_minor*item.quantity,
      'cart_item_id',case when p_source='cart' then item.cart_item_id else null end,
      'cart_revision',case when p_source='cart' then item.cart_revision else null end));
  end loop;
  if subtotal+s.shipping_fee_minor>9000000000000 then
    raise exception 'Order total is too large' using errcode='22023';
  end if;
  return jsonb_build_object('source',p_source,'address_id',a.id,'currency',s.currency,
    'subtotal_minor',subtotal,'shipping_minor',s.shipping_fee_minor,'total_minor',subtotal+s.shipping_fee_minor,
    'delivery_address',to_jsonb(a)-'id'-'user_id'-'is_default'-'created_at'-'updated_at',
    'items',quoted_items);
end $$;
revoke all on function public.quote_checkout(text,uuid,jsonb) from public,anon;
grant execute on function public.quote_checkout(text,uuid,jsonb) to authenticated;
commit;
