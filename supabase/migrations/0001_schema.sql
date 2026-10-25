-- Run once on the intended project, before 0002-0004. All money is PHP centavos.
begin;
create schema if not exists private;
revoke all on schema private from public;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (length(display_name) <= 120),
  phone text check (length(phone) <= 30),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('customer','admin'))
);
create table public.categories (
  id uuid primary key default gen_random_uuid(), name text not null,
  slug text not null unique, is_active boolean not null default true, sort_order integer not null default 0
);
create table public.products (
  id uuid primary key default gen_random_uuid(), category_id uuid not null references public.categories(id),
  name text not null check (length(name) between 1 and 160), slug text not null unique,
  description text not null default '', is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.products(category_id);
create table public.product_images (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id),
  storage_path text not null unique, sort_order integer not null default 0
);
create index on public.product_images(product_id,sort_order);
create table public.product_variants (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id),
  sku text not null unique, option_label text not null,
  price_minor bigint not null check (price_minor between 1 and 1000000000),
  stock_on_hand integer not null default 0 check (stock_on_hand >= 0),
  stock_reserved integer not null default 0 check (stock_reserved between 0 and stock_on_hand),
  is_active boolean not null default true, updated_at timestamptz not null default now(),
  unique(product_id,option_label)
);
create index on public.product_variants(product_id);
create table public.addresses (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  recipient text not null check (length(trim(recipient)) between 1 and 120),
  phone text not null check (phone ~ '^\+?[0-9 ()-]{7,25}$'),
  province text not null check (length(trim(province)) between 1 and 100),
  city text not null check (length(trim(city)) between 1 and 100),
  barangay text not null check (length(trim(barangay)) between 1 and 100),
  street text not null check (length(trim(street)) between 1 and 250),
  postal_code text not null check (postal_code ~ '^[0-9]{4}$'),
  instructions text not null default '' check (length(instructions) <= 500),
  is_default boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.addresses(user_id);
create unique index addresses_one_default on public.addresses(user_id) where is_default;
create table public.cart_items (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  variant_id uuid not null references public.product_variants(id), quantity integer not null check (quantity between 1 and 99),
  revision bigint not null default 1, updated_at timestamptz not null default now(), unique(user_id,variant_id)
);
create table public.shop_settings (
  id boolean primary key default true check(id), currency text not null default 'PHP' check(currency = 'PHP'),
  country text not null default 'PH' check(country = 'PH'),
  shipping_fee_minor bigint not null check(shipping_fee_minor between 0 and 10000000),
  reservation_minutes integer not null default 30 check(reservation_minutes between 15 and 60)
);
-- Demonstration default; the owner can change the fee before presenting.
insert into public.shop_settings(id,shipping_fee_minor) values(true,15000);
create table public.orders (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
  order_number text not null unique, idempotency_key uuid not null, request_fingerprint text not null,
  source text not null check(source in ('cart','buy_now')),
  payment_status text not null default 'pending' check(payment_status in ('pending','paid','expired','cancelled','needs_review')),
  fulfillment_status text not null default 'unfulfilled' check(fulfillment_status in ('unfulfilled','preparing','shipped','delivered')),
  currency text not null default 'PHP' check(currency = 'PHP'),
  subtotal_minor bigint not null check(subtotal_minor > 0), shipping_minor bigint not null check(shipping_minor >= 0),
  total_minor bigint not null check(total_minor = subtotal_minor + shipping_minor and total_minor <= 9000000000000),
  delivery_address jsonb not null check(jsonb_typeof(delivery_address) = 'object'),
  expires_at timestamptz not null, paid_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(user_id,idempotency_key), check(payment_status<>'paid' or paid_at is not null)
);
create index on public.orders(user_id,created_at desc);
create table public.order_items (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
  variant_id uuid references public.product_variants(id), sku text not null, product_name text not null,
  option_label text not null, image_path text,
  unit_price_minor bigint not null check(unit_price_minor > 0), quantity integer not null check(quantity between 1 and 99),
  line_total_minor bigint generated always as (unit_price_minor * quantity) stored,
  source_cart_id uuid, source_cart_revision bigint,
  unique(order_id,variant_id)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id),
  provider_product text not null default 'payment_session' check(provider_product = 'payment_session'),
  reference_id text not null unique, provider_id text unique, provider_business_id text,
  provider_payment_id text unique, payment_url text,
  expected_amount_minor bigint not null, currency text not null check(currency = 'PHP'),
  state text not null default 'reserved' check(state in ('reserved','creating','active','paid','expired','cancelled','creation_failed','unknown','needs_review')),
  provider_status text, claim_token uuid, failure_code text,
  expires_at timestamptz not null, last_checked_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(state<>'paid' or provider_payment_id is not null)
);
create index on public.payments(state,updated_at);
create table public.inventory_reservations (
  order_id uuid not null references public.orders(id), variant_id uuid not null references public.product_variants(id),
  quantity integer not null check(quantity > 0), state text not null default 'held' check(state in ('held','committed','released')),
  expires_at timestamptz not null, primary key(order_id,variant_id)
);
create index on public.inventory_reservations(state,expires_at);
create table public.webhook_events (
  id uuid primary key default gen_random_uuid(), dedupe_key text not null unique,
  event_type text not null, provider_id text not null,
  payment_id uuid references public.payments(id),
  state text not null default 'pending' check(state in ('pending','processed','ignored','needs_review')),
  attempts integer not null default 0, created_at timestamptz not null default now(), processed_at timestamptz
);
create index on public.webhook_events(state,created_at);

create function private.touch_row() returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  if tg_table_name = 'cart_items' then new.revision := old.revision + 1; end if;
  return new;
end $$;
do $$ declare t text; begin
  foreach t in array array['profiles','products','product_variants','addresses','cart_items','orders','payments'] loop
    execute format('create trigger touch_updated before update on public.%I for each row execute function private.touch_row()',t);
  end loop;
end $$;
-- Keep new tables closed even if the owner runs only this first migration today.
do $$ declare t text; begin
  foreach t in array array['profiles','user_roles','categories','products','product_images','product_variants','addresses','cart_items','shop_settings','orders','order_items','payments','inventory_reservations','webhook_events'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from public, anon, authenticated',t);
    execute format('grant all on public.%I to service_role',t);
  end loop;
end $$;
commit;
