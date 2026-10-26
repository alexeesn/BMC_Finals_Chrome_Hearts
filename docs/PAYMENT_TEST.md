# Place Order and Xendit test payment

This stage adds order submission, external hosted test payment, and My orders to the existing Flutter app.
It requires the already-applied migrations 0001–0005 and deployed Edge handlers. No additional SQL is needed.
An actual hosted PAY transaction has not yet been verified in this session.

## Before the first payment attempt

1. Rebuild the dashboard copies from the repository root if needed:

```powershell
node scripts/build-dashboard-functions.mjs
```

2. Supabase → Edge Functions → `create-payment` → Code: replace the code with the entire
   `supabase/dashboard/create-payment/index.ts` and Deploy updates. Keep JWT verification **ON**.
   The current bundle includes both session-ID response formats. A previous webhook-only update
   did not necessarily update this deployed function.
3. Update `reconcile-payments` with the entire current dashboard bundle too. Keep JWT verification
   **OFF**; it checks `RECONCILE_TOKEN` itself. The existing Vault/Cron job and tokens stay the same.
   Webhook and return-page setup must also already be complete.
4. For Chrome/web development, add this Supabase Edge Function Secret:

```text
Name: APP_ORIGINS
Value: http://localhost:5173,http://127.0.0.1:5173
```

   These are exact allowed browser origins, separated by commas. Do not enter a path or trailing slash.
   No new private key/token is needed. Native Android requests do not require a browser Origin.
   If the existing app is already running on a different port, allow that exact origin first.
   For the user's reported Edge session `http://localhost:63594/`, append `http://localhost:63594`
   to APP_ORIGINS (no trailing slash). Keep the same browser/port/site data until its interrupted
   checkout has been recovered; local preferences are scoped to the browser origin.
5. Stop the existing app (`q` or Ctrl+C), then from `ecommerce/`:

```powershell
flutter pub get
flutter run -d chrome --web-port 5173
```

   Use that stable port for web testing so both CORS and browser session/recovery storage are consistent.
   For an Android device/emulator, use `flutter run` and select Android instead.

## Demo checkpoints

1. Sign in using a customer app account. Use Buy Now or selected cart rows, choose an address,
   and inspect the backend quote.
2. Tap **Place Order** once. The backend validates the current selection and creates/reuses a pending
   order, reserves inventory, and prepares one Xendit test session. The app then shows canonical order
   snapshots and final totals read from Supabase. No order/payment status is written directly by Flutter.
3. Check the final total, items, address, and pending status. If the total changed since the quote,
   the screen calls out the change before you proceed. Then tap **Continue to Xendit**.
   It opens a separate browser tab/window or the device browser from a direct user tap.
   Only the same two test hostnames accepted by our backend are allowed in Flutter.
4. Follow the official test/simulation instructions for a payment method actually available to your
   Xendit test account. Do not assume that saving an API key enables every wallet/card method.
5. Close the hosted return page and return to the app. Tap **Refresh payment status** if needed.
   The order page polls pending status every 10 seconds while visible/in the foreground and refreshes
   after app resume. It never marks paid because a URL opened or a page closed.
6. Confirm **Paid** only after the backend's order and payment states both say paid. Check that
   fulfillment is separate (initially Preparing), and stock/cart changes occurred once.
7. Account → **My orders** lists the latest 50 owned orders. Open one to see its purchased item/address
   snapshots and payment/fulfillment state. Later catalog/address edits must not rewrite these snapshots.
8. Try an unpaid checkout separately. Closing a page leaves it pending. The worker confirms final provider
   expiry before releasing stock. A local elapsed timer disables payment opening but does not invent a final status.

## Interrupted checkout and retries

- Before a request is sent, the app saves its key and source/item/address IDs in owner/project-scoped local
  preferences. It stores no price authority, payment credentials, or address text there.
- This cache is a recovery convenience, not a financial ledger or guaranteed durable storage. Supabase orders
  are the source of truth; payment idempotency/claims are enforced by the transactional backend.
- Repeated taps are disabled. An interrupted response retains the same request/key. The app queries the owned
  order before retrying. An existing active/creating/unknown/terminal order never causes another provider creation.
- If the backend confirmed a validation error and no order exists for the key, the selection can be edited again.
- Account → My orders → **Resume checkout** restores an unfinished request. If a committed order exists, it opens
  that order. Unknown/creating provider outcomes remain pending for worker/owner review rather than blind recreation.
- A save failure stops submission. If browser/app data is cleared or recovery data cannot be read, inspect the
  canonical My orders list before intentionally starting another checkout; do not treat cache loss as payment failure.
- Changing accounts hides the prior account's cart, review, order details, and recovery data.

## Troubleshooting

| Result | Check |
| --- | --- |
| Web request has a CORS/network error | Exact `APP_ORIGINS`, browser address/port, latest deployed code, and function Invocations |
| 401 | Logged-in customer session and correct project; sign in again. Do not disable the function's JWT setting just to suppress the error. |
| 409 or uncertain setup | Open/refresh the existing order; keep the same checkout key. Inspect worker/provider evidence if it remains unknown. |
| Payment page does not open | Allow the popup and click Continue again; verify the saved test URL and session expiry. |
| Page returns but order stays pending | Inspect callback/worker status and captured provider evidence; do not manually mark paid. |
| Cart does not update immediately | Close the order flow/return from My orders or refresh Cart. Only matching unchanged source cart rows are removed after confirmed payment. |

## Local verification

```powershell
flutter analyze
flutter test
dart run test/order_model_checks.dart
```

Dart analysis and the standalone checks pass locally. The standalone checks execute URL restrictions, status/expiry
eligibility, recovery serialization, lost-response recovery, same-key retry, cache failure, definitive rejection,
and account-switch guards. Widget tests are authored/analyzed but cannot start in the assistant sandbox because
the Flutter SDK cache lockfile is outside its writable workspace. Device/browser and real-provider checks remain pending.
