# Backend API and recovery

This describes the local implementation. Hosted deployment and real test-account access have not been verified.

## App reads

- Active catalog: `categories`, `products`, `product_images`, and `catalog_variants`.
- `catalog_variants` exposes `available_stock`; the underlying `product_variants` table is backend-only.
- Customer-owned data: `profiles`, `addresses`, `cart_items`, `orders`, and `order_items`.
- `order_payment_summary` exposes safe payment state/URL for owned orders; admins can read store order summaries.
- Store money in centavos: `1200000` displays as PHP 12,000.00. Never reuse a displayed string as an authoritative checkout price.

## Checkout request

### Read-only review

After applying `migrations/0005_checkout_quote.sql`, a signed-in client can call
`quote_checkout(p_source, p_address, p_items)`. Source/items use the same shapes below,
and `p_address` must belong to the authenticated caller. Client prices and cart quantities
are ignored; the function reads active variants, availability, saved cart quantities,
and server shipping. It returns `items`, `delivery_address`, `subtotal_minor`,
`shipping_minor`, `total_minor`, `currency`, `source`, and `address_id`.

This is a read-only estimate at the time of the query: it creates no order/payment,
changes no cart rows, and holds no stock. Actual checkout must validate again.
Changing addresses or selected items requires a fresh review. No privileged key is used.

### Create the order and hosted payment

Call `create-payment` through the signed-in Supabase client. It requires both the normal project client key and the customer's session JWT; a client key alone is not login.

Buy Now body:

```json
{
  "source": "buy_now",
  "address_id": "<owned address UUID>",
  "idempotency_key": "<new checkout UUID>",
  "items": [{"variant_id": "<catalog variant UUID>", "quantity": 1}]
}
```

Cart body:

```json
{
  "source": "cart",
  "address_id": "<owned address UUID>",
  "idempotency_key": "<new checkout UUID>",
  "items": [{"cart_item_id": "<selected owned cart row UUID>"}]
}
```

Only selected cart rows are included. The backend obtains their quantities/revisions. Buy Now accepts exactly one variant. Quantities are 1–99 and checkout is limited to 20 lines. Posted customer IDs/prices are ignored; ownership comes from validated Auth identity.

Reuse the same idempotency key after an interrupted request with the same payload. Do not generate a new key just because a timeout occurred. A changed address/items/source requires a new intended checkout after reviewing any previous pending order.

The response contains `order_id`, `order_number`, `payment_status`, `payment_state`, `total_minor`, `currency`, `expires_at`, and an active `payment_url` when available. Internal claims and delivery snapshots are not returned by this endpoint.

- 200: inspect state; open a URL only if active. A paid/expired/cancelled response is not a new payable session.
- 400: invalid selection/address/quantity/stock or reuse of a key for a different request.
- 401: missing/expired customer session.
- 409: creation already running or its result is uncertain; refresh the existing order instead of creating another payment.
- 502/503: provider/backend unavailable or configuration issue; refresh the existing order before retrying with the same key.

## Addresses and admin operations

Customer address insert/update permissions exclude `is_default`. After saving an address, use the authenticated `set_default_address` RPC with `p_address` to atomically change the default. Deleting the default may leave no default; checkout still requires an explicit valid address.

Admin-only authenticated RPCs:

- `admin_variants()`: list internal variant/stock records.
- `admin_save_variant(p_id,p_product,p_sku,p_option,p_price,p_stock,p_active)`: pass null `p_id` for a new variant. `p_price` is centavos; stock cannot fall below active reservations.
- `admin_update_fulfillment(p_order,p_status)`: paid orders only, Preparing → Shipped → Delivered, with safe repeated same-state calls.

Admins can add/edit products/categories/image metadata under RLS. Archive catalog entries using `is_active`; no customer-facing hard-delete operations are provided. Image files are uploaded to new paths. Role promotion remains an owner action through the setup script.

## Callback processing

Configure `payment_session.completed` and `payment_session.expired` destinations to `xendit-webhook`. Other event types are ignored by this implementation. Matching verification token is required before any database or provider action.

Session IDs may arrive as `data.payment_session_id` or the older/dashboard `data.id`. Both are accepted; conflicting values are rejected. The provider's session response supports the same aliases.

After token verification, explicitly non-PAY session events and references outside this shop's `bmc_<order UUID>` namespace are acknowledged with HTTP 200 and an `ignored` reason, without database/provider calls. Xendit's supplied dashboard fixture observed during setup uses `id`, `reference_id: test_session`, `session_type: SAVE`, and IDR. Its successful acknowledgement proves endpoint/token handling, not a completed shop payment. Missing/malformed IDs on the shop's PAY events are still rejected; real payment evidence requirements are unchanged.

The handler durably records a deduplicated inbox event and queries the provider using the server's test key. It checks the session's reference/amount/currency/merchant/flow, then retrieves successful captured payment evidence before applying paid status. An authorized/partially captured payment is insufficient. An expired session with a still-payable asynchronous attempt retains its hold for reconciliation.

Failures return retryable errors; the stored inbox can also be retried by the worker. The Cron worker is required to handle missed callbacks and expiries; it is not optional when demonstrating complete stock lifecycle handling.

## Recovery worker

`reconcile-payments` requires POST, JSON body, and the secret `x-reconcile-token` header. A normal scheduled body is `{}`. It polls bounded batches, retries pending inbox work, and lists uncertain creations without a saved provider ID under `unresolved`.

If Xendit created a session but its response was lost:

1. The project owner finds the order's `reference_id` in the Xendit Test dashboard.
2. Obtain the matching `payment_session_id`.
3. Use the worker's dashboard tester with its worker header and body:

```json
{"session_ids": ["<matching ps-... identifier>"]}
```

4. The worker fetches that resource under the server key and attaches it only through its verified merchant reference. Never change a customer order to paid by hand just to resolve an error.

If the owner has conclusively verified that an uncertain creation produced no provider resource, the owner may release it using SQL Editor. Replace the UUID; this is not a customer operation:

```sql
select public.ecom_creation_failed(
  '<order UUID>'::uuid,
  (select claim_token from public.payments where order_id='<order UUID>'::uuid),
  true,
  'OWNER_CONFIRMED_NO_PROVIDER_RESOURCE'
);
```

The function refuses to release an order that has an attached provider resource or has already left the uncertain creation state. A local countdown alone is not evidence for this operation. Orders flagged `needs_review` require inspection of provider evidence and reservations; the package does not automate refunds or forced paid transitions.

## Integration references

- [Create a Session](https://docs.xendit.co/apidocs/create-session)
- [Get Session](https://docs.xendit.co/apidocs/get-session)
- [Get Payment](https://docs.xendit.co/apidocs/get-payment)
- [Get Payment Request](https://docs.xendit.co/apidocs/get-payment-request)
- [Supabase authorization headers](https://supabase.com/docs/guides/functions/auth-headers)
