# Project status

Last updated: 2026-10-26 (Asia/Singapore).

## Current phase

The user explicitly confirmed all six database checks are OK and supplied the Supabase publishable key for the Flutter app. Implemented the Flutter foundation/auth/catalog milestone locally in the existing app. Next: run the app on the user's device and verify catalog loading and login/account role. Hosted app access, widget tests, APK build, and a real PAY transaction remain unverified.

## Completed

- Discussed the school ecommerce concept, stack, shopping features, and admin panel.
- Inspected the user's existing local repository after file access became available.
- Identified the existing Flutter app in `ecommerce/`.
- Created root `AGENTS.md`, `PROJECT_PLAN.md`, this status file, and `docs/CLASS_REFERENCE.md`.
- Recorded the user's instruction to use their own project, without depending on the instructor's repository.
- Prepared `docs/SCREEN_PLAN.md` with the customer/admin navigation map, four detailed shopping screen layouts, authentication proposal, and loading/empty/error states.
- Created `docs/previews/shopping-flow.html`, an offline interactive visual proposal for Home, Product Details, Cart, and Checkout. It uses fictional browser-memory data and makes no backend/payment calls.
- Applied the user's dark-theme request throughout the preview: black/charcoal backgrounds, silver primary controls, light text, dark dialogs, and Gothic-inspired display typography. Dark theme is now a confirmed design requirement.
- User accepted the updated dark-theme preview ("guds na") and asked for the next step. Use its four-screen layout as the implementation baseline, subject to later feedback; sample products, prices, addresses, shipping fee, and shop label remain placeholders.
- Added `docs/DATABASE_PLAN.md`: proposed tables/relationships, access matrix, trusted admin provisioning, centavo amounts, transactional checkout, stock reservation/reconciliation, and payment/fulfillment states.
- Added `docs/SUPABASE_XENDIT_SETUP.md` in Taglish: account/project setup, client credentials, SQL execution order, secrets, Edge Function deployment, webhook registration, Flutter connection, expiry worker, test checkpoints, and troubleshooting.
- Checked current official Supabase/Xendit documentation. The local code implements one-time, automatic-capture PHP/PH test Payment Sessions; it does not implement the instructor's legacy invoice API. Account access has not been verified.
- Added four migrations, fictional demo seed, 14 tables, RLS/grants, safe catalog/payment views, transactional checkout, stock reservations, payment application, default-address RPC, and admin catalog/fulfillment RPCs.
- Added `create-payment`, `xendit-webhook`, `reconcile-payments`, and `payment-return` TypeScript handlers, plus `supabase/config.toml`.
- Added the Node dashboard bundler and generated self-contained copies under `supabase/dashboard/`. These copies are ignored by Git; rebuild with `node scripts/build-dashboard-functions.mjs` after pulling or changing canonical source.
- Added owner setup scripts for read-only verification, admin promotion, and hosted Cron scheduling with preconfigured Vault secrets.
- Updated the detailed setup guide and added `docs/START_HERE.md` and `docs/BACKEND_API.md` for the first dashboard activity and integration/recovery details.
- The user asked why migrations/TS were needed. Clarified SQL is for database setup; TS is the Edge Function code pasted into the Supabase editor; the Xendit dashboard receives the deployed webhook URL. The user accepted this explanation and asked to continue.
- The user ran `0001_schema.sql` in their Supabase SQL Editor and reported success after choosing Run and enable RLS. This is user-reported; hosted tables/policies have not been independently inspected.
- The user reported success for `0002_permissions.sql` ("guds na").
- The user reported `0003_business_functions.sql` is complete.
- The user reported `0004_storage.sql`/Storage setup is successful ("goods na rin").
- The user reported successful sample catalog seeding ("goods na anong next"). All four migrations and seed are user-reported complete. Read-only verification is next.
- Supplied the six-row read-only verification query. The user requested the next step without explicitly confirming every status is OK; verification results remain unconfirmed.
- Clarified the requested key permissions: Money-In Write, Money-Out None. The user reported saving the API key in Supabase Secrets as instructed (`XENDIT_SECRET_KEY`). No key value was shared or inspected.
- The user reported saving the webhook verification token as `XENDIT_WEBHOOK_TOKEN`. No token value was shared or inspected.
- The user reported saving `RECONCILE_TOKEN` after the dashboard generation instructions. All three secret saves are user-reported complete; values were not shared or inspected.
- Supplied browser-editor deployment instructions and the generated file for `payment-return`, with JWT verification OFF. The user requested the next step without explicitly reporting the deployment result; keep its deployment/runtime status unverified.
- Supplied the generated `create-payment` deployment instructions with JWT verification ON. The user requested the next step; no runtime result or explicit deployment confirmation was supplied.
- Supplied the generated `xendit-webhook` deployment instructions with JWT OFF and asked the user to retain its public function URL for registration. The user requested the next step; deployment and URL are not explicitly confirmed.
- Supplied the generated `reconcile-payments` deployment instructions with JWT OFF and worker-token verification. The user requested the next step, then resumed after an interruption. Do not infer runtime success or scheduler setup from that request alone.
- The user confirmed Payment Session settings exist, and supplied test responses from the reachable `xendit-webhook` endpoint: HTTP 400 with our `Invalid provider resource ID` error. The test request has `data.id`, `reference_id: test_session`, `session_type: SAVE`, country ID, currency IDR. Its callback token was masked; no secret value was collected.
- Fixed session-ID aliases (`id` and `payment_session_id`) without relaxing resource validation. Authenticated non-PAY/unrelated-reference events are explicitly ignored with HTTP 200 and no order/provider calls; shop PAY events retain full verification. Conflicting or missing shop session IDs remain errors.
- Regenerated all four browser-editor bundles. The local regression suite now has 28 passing handler tests, including completed/expired SAVE fixtures, alias-compatible PAY callbacks/provider responses, wrong tokens, unrelated references, conflicting IDs, and missing IDs. No SQL migration is needed for this fix.
- The user reported the updated webhook test returns HTTP 200 ("guds na 200 na sya"). Treat this as confirmed dashboard sample delivery/acknowledgement, not evidence that a real order was paid. Separate results for each event were not provided.
- During scheduler setup, the user reported Cron is already Installed and sees a cleanup option. Treat `pg_cron` as user-reported installed; cleanup is separate from installing/enabling the module. `pg_net` installation remains unconfirmed.
- After `pg_net` instructions, the user reported it is good and asked to proceed. Treat Cron and pg_net as user-reported ready. Vault secrets and scheduled-job creation are next and not yet confirmed.
- The user reported saving both Vault entries after the instructions (`bmc_project_url`, `bmc_reconcile_token`). Values were not requested or inspected. Proceed to scheduling SQL; no scheduled-job result is confirmed yet.
- After the scheduling SQL and active-job instructions, the user reported success ("guuds na anong next"). Treat schedule setup as user-reported complete; no worker HTTP status or response body has been supplied yet.
- After instructions to inspect `reconcile-payments` Invocations for HTTP 200 and the empty-work response, the user reported "goods na anong next". Treat the worker check as user-reported successful, without independently inspected logs or an exact response body. Next guide admin account creation and promotion.
- After the Authentication account creation/UID instructions, the user reported "guds na anong next". Intended admin Auth account is user-reported ready; admin-role provisioning is not yet confirmed. No email, password, or UUID was collected.
- Admin promotion initially stopped safely because the declaration still contained the zero UUID. Explained replacing only the declaration with the intended Auth UID, leaving the guard unchanged. The user then reported success ("ayon guds na anong next"). Promotion is user-reported complete; the exact role-table result was not supplied.
- The user explicitly confirmed all six verification statuses are OK ("guds na puro ok"). This closes the pending database-count/RLS/settings checkpoint as user-reported passed.
- The user chose to supply the public client key. Stored the supplied publishable key and known project URL in `ecommerce/lib/config/app_config.dart`, with optional compile-time overrides. No privileged key/password was supplied or embedded.
- Replaced the existing Flutter counter app with a dark collection/search/category screen, product details and selectable available variants, image fallbacks, Supabase initialization, persisted auth, login/register with email-confirmation handling, sign-out, and own profile/customer/admin role display. Added Android release Internet permission and `supabase_flutter` 2.18.3; offline dependency resolution generated the lockfile/config and platform plugin registrants.
- Added an injectable gateway and five tests covering centavo formatting, catalog search/sold-out variants, failed-fetch retry, login validation/logout/account switching, and confirmation-required signup. Tests are authored and statically analyzed, not executed successfully in this environment.
- Added `docs/FLUTTER_SETUP.md` and updated the app README. The user still needs to run `flutter pub get` / `flutter run` and inspect the actual catalog and account. Cart, addresses, checkout, orders, and admin management UI remain pending milestones.

## Observed codebase

- `ecommerce/lib/main.dart` initializes Supabase through a retryable startup screen; `app.dart` defines the dark theme and Collection/Account navigation.
- `ecommerce/lib/screens/` contains catalog, product detail, account, and email/password auth screens; `services/shop_gateway.dart` uses the existing hosted schema and safe variant view.
- `ecommerce/test/widget_test.dart` contains five model/widget tests with a fake gateway; see verification limits below.
- `ecommerce/pubspec.yaml` includes `supabase_flutter: ^2.18.3`; no payment UI package is needed in this milestone.
- The app has Android, iOS, web, Windows, macOS, and Linux folders. Final delivery targets still need confirmation.
- `ecommerce/README.md` links the actual app setup/checkpoints.
- Existing backend modifications were preserved. The assistant did not commit or push.

Backend and the first Flutter milestone are implemented locally. Hosted migrations/seed, secrets, sample webhook HTTP 200, scheduled-worker check, admin promotion, and all six SQL checks are user-reported successful. Actual customer auth/catalog access and a PAY transaction have not been independently verified.

## Immediate next step

Run the existing app from `ecommerce/` using `flutter pub get`, then `flutter run`. Verify three seeded products load, filtering/details/stock work, and Account sign-in using the intended Auth account shows Admin account. Confirm session persistence and sign-out; then register a distinct customer and verify Customer account. The local gateway uses the real schema but hosted runtime access is unverified. See `docs/FLUTTER_SETUP.md`. Do not start the cart/checkout milestone until this app foundation has been checked or the user requests that work.

Before relying on the worker/real checkout, use the current generated bundles for `reconcile-payments` and `create-payment`; they include session-ID response compatibility too. Their previous deployment instructions were supplied but their runtime results were not verified.

Public webhook URL supplied by the user: `https://pxxendicdpkdjuhidiur.supabase.co/functions/v1/xendit-webhook`. Project URL: `https://pxxendicdpkdjuhidiur.supabase.co`. These are not secrets. The user confirmed a 200 sample response after the fix. Do not store/repeat webhook token headers. Actual PAY/order verification remains pending.

All three secrets are already user-reported saved; do not regenerate them. Keep the worker token available securely for the later Vault configuration; never request or record its value.

The `supabase/setup/verify.sql` checkpoint is now explicitly user-reported all six OK. Do not reset the project or rerun completed migrations.

Then follow the full guide for Auth/admin setup, Xendit Test Mode secrets, browser-editor function deployment, webhook registration, and Cron/Vault worker configuration. Actual project/account access remains unverified. Do not claim connection success until the hosted checks and a genuine test transaction pass.

Current local Flutter milestone is implemented, awaiting device/runtime verification. The next implementation milestone is persistent cart, Buy Now, addresses, and checkout after the current foundation check. Continue using the existing `ecommerce/` app and accepted dark layout.

Keep the one-store Android app, shared customer/admin app, and fixed shipping fee as proposals until confirmed through discussion or an implementation request. The user has confirmed the dark-theme direction; the final font, shop name, and product imagery remain open.

## Open decisions

- Final app/shop display name.
- Android-only delivery and whether the rubric requires a separate admin website.
- Sample products, images, categories, and applicable variants.
- The four-screen dark layout is accepted; final branding and typography assets remain open. `CH / COLLECTION` is only a preview label.
- Shipping fee and address-entry approach.
- Working backend defaults: PHP/PH, PHP 150 sample shipping, 30-minute reservation, safe expiry reconciliation, no initial paid-order cancellation/refunds, and revision-aware paid-cart cleanup. These are configurable baseline choices, not independently confirmed business rules.
- Supabase and Xendit accounts are in use; migrations 0001–0004, seed, secrets, admin promotion, and six database checks are user-reported complete. Public client configuration is supplied. App runtime access, provider API access, and actual PAY behavior remain unverified.
- Any extra grading or presentation requirements.

Resolve questions at the relevant milestone instead of asking everything at once.

## Verification and environment

- Workspace: `C:\Users\teodo\OneDrive\Documents\BMC LOURENCE X XEESH`.
- Flutter app directory: `ecommerce/`.
- Earlier file-access failures are historical; local read/write works in the resumed session.
- Latest backend test command `node supabase/tests/run-local.mjs` passed on an isolated PostgreSQL 18.6 cluster: fresh migrations/seed, RLS/role isolation, server totals, idempotency, snapshots, stock/payment transitions, cart cleanup, inbox recovery, and fulfillment checks.
- Two concurrent last-item checkouts were tested in separate database connections: one reservation succeeded, the other correctly failed for insufficient stock.
- All 21 Node tests passed using injected HTTP fixtures for Edge behavior, including tokens, ownership, prices, duplicate creation, unknown outcomes, captured payment evidence, partial/wrong-currency rejection, and worker processing.
- After the dashboard-payload compatibility fix, all 28 handler tests passed via `node --test supabase/tests/edge.test.mjs`. Canonical and regenerated TypeScript also passed Node syntax checks. SQL was unchanged for this patch; the earlier database/concurrency checks remain the latest SQL verification.
- Canonical and generated TypeScript passed Node syntax checks. These are not Deno type/compiler checks; Deno is not installed.
- Regenerated all four self-contained dashboard files before guiding deployment; `payment-return` passed a fresh Node syntax check. Hosted compilation/deployment is still pending user confirmation.
- The local database suite uses minimal Auth/Storage stubs, not the full Supabase platform. Hosted JWTs, Storage behavior, Edge deployment, Vault/pg_net/Cron, available Xendit channels, and an actual test payment remain unverified. `supabase/tests/bootstrap.sql` must never be run on hosted Supabase.
- Temporary test servers were stopped. Test logs were retained in the printed temp folders; the latest successful run used `bmc-ecom-test-PQa7xi`.
- The PowerShell test runner encountered script execution policy; it was replaced by a normal Node runner without changing that policy.
- Earlier preview checks passed for syntax, document structure, and main text contrast. Automated browser rendering was unavailable because headless Edge's GPU process failed; user accepted the visual preview after review.
- Flutter milestone: `dart --suppress-analytics analyze` passed with No issues found for the whole app and test files. Dart formatter passed. `dart pub get --offline` resolved cached dependencies successfully; its initial process exit was nonzero only because telemetry attempted to touch a file outside the workspace. Subsequent Dart commands use `--suppress-analytics`.
- Standard Flutter CLI/test startup is blocked by write access to `C:\flutter\bin\cache\lockfile`. No SDK permission/policy changes were made. Widget tests and APK/device builds remain unrun; do not report them as passing.
- A read-only REST smoke-check using the public key failed DNS resolution for the project hostname from this restricted environment. No hosted response was obtained, and no auth users/orders/payments were created by the assistant.
- No actual account credentials were collected or verified. Test fixtures contain deliberately fake key strings.
- Final documentation checks passed: 10 Markdown files, 31 local links, balanced fences, and all four generated dashboard copies matched canonical source. `git diff --check` passed with line-ending notices only; generated copies are ignored by Git as intended.
- No commits, pushes, or hosted deployments were performed by the assistant. The user reported successful hosted execution of migrations 0001–0004 and seed.

## Handoff

Read `AGENTS.md`, this file, and `PROJECT_PLAN.md` before continuing. Follow the latest user instructions and update these notes after meaningful progress. Use session resume for the conversation history; these documents preserve the project decisions and current state.
