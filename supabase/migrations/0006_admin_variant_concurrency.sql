-- UI stock edits must not overwrite a checkout/reservation made after the form loaded.
begin;
create function public.admin_save_variant_checked(
  p_id uuid,p_product uuid,p_sku text,p_option text,p_price bigint,p_stock integer,p_active boolean,
  p_expected_updated_at timestamptz
) returns uuid language plpgsql security definer set search_path = '' as $$
declare current_variant public.product_variants;
begin
  if not private.is_admin() then raise exception 'Admin required' using errcode='42501'; end if;
  if p_id is not null then
    select * into current_variant from public.product_variants where id=p_id for update;
    if not found or current_variant.product_id<>p_product then
      raise exception 'Variant not found for this product' using errcode='22023';
    end if;
    if p_expected_updated_at is null or current_variant.updated_at is distinct from p_expected_updated_at then
      raise exception 'Variant changed since this form loaded. Refresh before saving stock or prices' using errcode='40001';
    end if;
  end if;
  return public.admin_save_variant(p_id,p_product,p_sku,p_option,p_price,p_stock,p_active);
end $$;
revoke all on function public.admin_save_variant_checked(uuid,uuid,text,text,bigint,integer,boolean,timestamptz)
  from public,anon;
grant execute on function public.admin_save_variant_checked(uuid,uuid,text,text,bigint,integer,boolean,timestamptz)
  to authenticated;
commit;
