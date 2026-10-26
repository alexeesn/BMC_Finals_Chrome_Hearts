# School ecommerce backend

Start with [the step-by-step setup guide](../docs/SUPABASE_XENDIT_SETUP.md). The Flutter app remains in `../ecommerce/`; this folder contains the backend package.

## What to use

- `migrations/0001_schema.sql` through `0005_checkout_quote.sql`: run once, in order, on the intended clean Supabase project. If 0001–0004 are already applied, run only 0005 for the new read-only checkout review; do not rerun the earlier migrations.
- `migrations/0006_admin_variant_concurrency.sql`: add after 0005 for the admin app's checked stock/price saves. See [admin setup](../docs/ADMIN_SETUP.md); existing projects run only this new migration.
- `seed.sql`: fictional demo catalog; safe to repeat without overwriting existing seeded records.
- `setup/verify.sql`: read-only database/bucket checks.
- `setup/promote-admin.sql`: owner-run admin promotion after replacing the placeholder UUID.
- `setup/schedule-reconciliation.sql`: hosted Cron setup after Vault secrets and Edge deployment.
- `functions/`: canonical, dependency-free TypeScript handlers.
- `tests/`: local test support. **Never paste `tests/bootstrap.sql` into hosted Supabase.** It mocks Auth and Storage for a disposable database.

## Function names

| Function | Auth | Purpose |
| --- | --- | --- |
| `create-payment` | User JWT; validates it through Supabase Auth | Trusted checkout and Xendit test Payment Session |
| `xendit-webhook` | Xendit verification token | Durable callback inbox and provider-verified payment update |
| `reconcile-payments` | `x-reconcile-token` matching `RECONCILE_TOKEN` | Recheck payments, retry inbox work, and recover missed responses |
| `payment-return` | Public read-only GET | Static return page; never marks an order paid |

Only Xendit development keys are accepted. The implementation is for `/sessions`, one-time PAY, hosted page, automatic capture, and PHP/PH. There is no legacy invoice fallback. Account access and available test channels must be checked during deployment.

## Browser-editor copies

From the repository root:

```powershell
node scripts/build-dashboard-functions.mjs
```

Copy each generated `supabase/dashboard/<function>/index.ts` into the Supabase editor for that function. The generated file includes the shared code. Do not paste only a short canonical entry file with an unresolved relative import. Generated copies are ignored by Git and can be rebuilt after checkout.

## Local validation

Node 24+ and PostgreSQL binaries are sufficient; Docker, Deno, and npm packages are not required for these tests.

```powershell
node supabase/tests/run-local.mjs
```

Default PostgreSQL binary folder is `C:\Program Files\PostgreSQL\18\bin`. Pass another folder as the first argument if needed. The runner creates a fresh temporary cluster, binds it to loopback on a temporary port, runs all migrations/security/state checks, races two last-item checkouts, runs mocked handler tests, and stops the test server. Logs are retained in the printed temp folder. It does not connect to your existing PostgreSQL service or Supabase account.

Handler-only checks:

```powershell
node --test supabase/tests/edge.test.mjs
```

Local tests cover PostgreSQL behavior and injected HTTP responses. They do not emulate the full Supabase platform, run Deno's deployment compiler, validate a real customer JWT, or charge an actual Xendit test resource. Hosted Auth/Storage/Edge/Cron and an end-to-end test payment still need account-level verification.

## Implementation behavior

- Prices/fees are trusted integer centavos from the database, converted to PHP amounts only at the Xendit boundary.
- Checkout is idempotent per customer/key and atomically reserves inventory.
- Only one request can claim creation of a provider resource for an order.
- A creation timeout keeps stock held until reconciliation; it never blindly retries payment creation.
- Webhook payload status/amount is not trusted. The backend fetches the session and, for a claimed success, its captured payment evidence.
- Session IDs support both `payment_session_id` and `id` payload fields, with conflicting IDs rejected. Authenticated non-PAY/unrelated-reference fixtures receive an ignored acknowledgement without order mutations.
- Duplicate/out-of-order updates cannot consume inventory twice or regress a paid order.
- Cart cleanup checks the original source-row revision; Buy Now leaves the cart intact.
- Role assignments and order/payment/inventory mutations are inaccessible to customer direct writes.
- Product image uploads use new immutable paths; overwrite/delete remains owner-only in this package to protect order-linked imagery.

Recovery instructions and API payloads are in [BACKEND_API.md](../docs/BACKEND_API.md).
