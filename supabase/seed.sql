-- Fictional school-demo products and prices, not verified Chrome Hearts retail data.
begin;
insert into public.categories(id,name,slug,sort_order) values
('10000000-0000-4000-8000-000000000001','Clothing','clothing',1),
('10000000-0000-4000-8000-000000000002','Jewelry','jewelry',2),
('10000000-0000-4000-8000-000000000003','Accessories','accessories',3)
on conflict(id) do nothing;
insert into public.products(id,category_id,name,slug,description) values
('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Archive Tee','archive-tee','Fictional demo cotton tee. Product image pending.'),
('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Silver Band','silver-band','Fictional demo jewelry item. Product image pending.'),
('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003','Everyday Cap','everyday-cap','Fictional demo accessory. Product image pending.')
on conflict(id) do nothing;
insert into public.product_variants(id,product_id,sku,option_label,price_minor,stock_on_hand) values
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','DEMO-TEE-S','S',1200000,4),
('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','DEMO-TEE-M','M',1200000,6),
('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000001','DEMO-TEE-L','L',1200000,3),
('30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000001','DEMO-TEE-XL','XL',1200000,0),
('30000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000002','DEMO-RING-8','US 8',1800000,3),
('30000000-0000-4000-8000-000000000006','20000000-0000-4000-8000-000000000002','DEMO-RING-9','US 9',1800000,2),
('30000000-0000-4000-8000-000000000007','20000000-0000-4000-8000-000000000003','DEMO-CAP','One size',850000,5)
on conflict(id) do nothing;
commit;
