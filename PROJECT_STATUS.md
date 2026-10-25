# Project status

Last updated: 2026-10-25 (Asia/Singapore).

## Current phase

The local backend package is prepared and locally tested. The user reported successful hosted execution of migrations 0001 and 0002. Next: migration 0003. Remaining migrations, seed/verification, Edge deployment, and actual Xendit Test Mode verification are pending. Flutter ecommerce implementation has not started.

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
- The user reported success for `0002_permissions.sql` ("guds na"). Proceed to migration 0003; do not rerun 0001/0002.

## Observed codebase

- `ecommerce/lib/main.dart` contains the Flutter starter counter application.
- `ecommerce/test/widget_test.dart` contains the starter counter widget test.
- `ecommerce/pubspec.yaml` has Flutter and `cupertino_icons` runtime dependencies; Supabase and payment packages have not been added.
- The app has Android, iOS, web, Windows, macOS, and Linux folders. Final delivery targets still need confirmation.
- Existing `ecommerce/README.md` is the starter README.
- Git status was clean before this documentation change.

Backend source files have been implemented locally. The user has applied the first two hosted SQL migrations; no hosted Edge Function or Flutter ecommerce feature has been deployed in this conversation. Flutter and PostgreSQL executables were found locally; no Flutter build or actual account configuration has been independently verified.

## Immediate next step

Guide the user through `supabase/migrations/0003_business_functions.sql`: open a new SQL Editor query in the same project, paste the entire file content, and Run. Migrations 0001/0002 are already user-reported successful; do not rerun them. After 0003 succeeds, continue with 0004, seed, and verification in order. Do not reset the project or rerun successful run-once migrations blindly.

Then follow the full guide for Auth/admin setup, Xendit Test Mode secrets, browser-editor function deployment, webhook registration, and Cron/Vault worker configuration. Actual project/account access remains unverified. Do not claim connection success until the hosted checks and a genuine test transaction pass.

Next local app milestone after backend setup: Flutter foundation, Supabase initialization, authentication, and catalog. Use the existing `ecommerce/` app and accepted dark layout; do not scaffold another project.

Keep the one-store Android app, shared customer/admin app, and fixed shipping fee as proposals until confirmed through discussion or an implementation request. The user has confirmed the dark-theme direction; the final font, shop name, and product imagery remain open.

## Open decisions

- Final app/shop display name.
- Android-only delivery and whether the rubric requires a separate admin website.
- Sample products, images, categories, and applicable variants.
- The four-screen dark layout is accepted; final branding and typography assets remain open. `CH / COLLECTION` is only a preview label.
- Shipping fee and address-entry approach.
- Working backend defaults: PHP/PH, PHP 150 sample shipping, 30-minute reservation, safe expiry reconciliation, no initial paid-order cancellation/refunds, and revision-aware paid-cart cleanup. These are configurable baseline choices, not independently confirmed business rules.
- A Supabase project is in use and migrations 0001/0002 are user-reported successful. Its project reference/settings are not recorded; Xendit test-account readiness and Payment Sessions access remain unverified.
- Any extra grading or presentation requirements.

Resolve questions at the relevant milestone instead of asking everything at once.

## Verification and environment

- Workspace: `C:\Users\teodo\OneDrive\Documents\BMC LOURENCE X XEESH`.
- Flutter app directory: `ecommerce/`.
- Earlier file-access failures are historical; local read/write works in the resumed session.
- Latest backend test command `node supabase/tests/run-local.mjs` passed on an isolated PostgreSQL 18.6 cluster: fresh migrations/seed, RLS/role isolation, server totals, idempotency, snapshots, stock/payment transitions, cart cleanup, inbox recovery, and fulfillment checks.
- Two concurrent last-item checkouts were tested in separate database connections: one reservation succeeded, the other correctly failed for insufficient stock.
- All 21 Node tests passed using injected HTTP fixtures for Edge behavior, including tokens, ownership, prices, duplicate creation, unknown outcomes, captured payment evidence, partial/wrong-currency rejection, and worker processing.
- Canonical and generated TypeScript passed Node syntax checks. These are not Deno type/compiler checks; Deno is not installed.
- The local database suite uses minimal Auth/Storage stubs, not the full Supabase platform. Hosted JWTs, Storage behavior, Edge deployment, Vault/pg_net/Cron, available Xendit channels, and an actual test payment remain unverified. `supabase/tests/bootstrap.sql` must never be run on hosted Supabase.
- Temporary test servers were stopped. Test logs were retained in the printed temp folders; the latest successful run used `bmc-ecom-test-PQa7xi`.
- The PowerShell test runner encountered script execution policy; it was replaced by a normal Node runner without changing that policy.
- Earlier preview checks passed for syntax, document structure, and main text contrast. Automated browser rendering was unavailable because headless Edge's GPU process failed; user accepted the visual preview after review.
- `git status --short -- ecommerce` showed no app changes. No Flutter analysis/tests or APK builds were run in this backend task.
- No actual account credentials were collected or verified. Test fixtures contain deliberately fake key strings.
- Final documentation checks passed: 10 Markdown files, 31 local links, balanced fences, and all four generated dashboard copies matched canonical source. `git diff --check` passed with line-ending notices only; generated copies are ignored by Git as intended.
- No commits, pushes, or hosted deployments were performed by the assistant. The user reported successful hosted execution of migrations 0001/0002.

## Handoff

Read `AGENTS.md`, this file, and `PROJECT_PLAN.md` before continuing. Follow the latest user instructions and update these notes after meaningful progress. Use session resume for the conversation history; these documents preserve the project decisions and current state.
