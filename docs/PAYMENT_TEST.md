# Place Order and Xendit test payment

This stage adds order submission, external hosted test payment, and My orders to the existing Flutter app.
It requires the already-applied migrations 0001–0005 and deployed Edge handlers. No additional SQL is needed.
The user has reported a successful hosted test payment showing Paid, followed by the
admin Shipped → Delivered flow. The assistant has not independently inspected hosted records.

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
   The return endpoint intentionally shows a plain-text message. Supabase rewrites default-host
   HTML responses to text/plain; if you see HTML source, update only `payment-return` from its
   current dashboard bundle with JWT OFF. Open the return URL directly to verify the fix without
   paying again. See [Supabase routing behavior](https://supabase.com/docs/guides/functions/http-methods).
   The order page polls pending status every 10 seconds while visible/in the foreground and refreshes
   after app resume. It never marks paid because a URL opened or a page closed.
6. Confirm **Paid** only after the backend's order and payment states both say paid. Check that
   fulfillment is separate (initially Preparing), and stock/cart changes occurred once.
7. Account → **My orders** lists the latest 50 owned orders. Open one to see its purchased item/address
   snapshots and payment/fulfillment state. Later catalog/address edits must not rewrite these snapshots.
8. Try an unpaid checkout separately. Closing a page leaves it pending. The worker confirms final provider
   expiry before releasing stock. A local elapsed timer disables payment opening but does not invent a final status.

## Selected cart items and stock

Use Xendit Test Mode and one account throughout. Choose a test variant with no outstanding
reservations or other activity while checking stock. Do not change its stock during this check.

1. Admin panel → Catalog → Photos & stock: note the variant's **On hand**, **Reserved**, and
   **Available** values. Start with Reserved = 0 and Available at least 1.
2. Return to the shop. Add quantity 1 of that variant and a different product/variant to Cart.
   Select only the first cart row; leave the second row unchecked.
3. Check out the selected row, verify the review contains only that variant at quantity 1,
   then Place Order and complete the Xendit test payment. Keep the cart unchanged while paying.
4. Once the order says Paid, return to Cart and refresh. The purchased row should be removed;
   the unchecked row should remain.
5. Reopen Photos & stock. With no other activity, expect On hand = original minus 1,
   Reserved = 0, and Available = original minus 1.
6. Refresh the same Paid order twice, then refresh Photos & stock again. Stock should remain
   at the step-5 value and My orders should contain only one order for this checkout.

If a result differs, record the order number, quantity, stock before/after, and exact message.
This checkpoint does not establish duplicate webhook handling, Buy Now cart preservation,
expiry release, or customer isolation; those remain separate checks.

## Buy Now preserves the saved cart

1. Use a product/variant with at least 2 available units. Keep quantity 1 of it in Cart,
   and note any other cart rows and their quantities.
2. Open that same product in the shop, select the same variant at quantity 1, and tap **Buy Now**.
3. In checkout review, expect exactly that one variant at quantity 1. Place Order and complete
   the Xendit Test Mode payment, keeping the cart unchanged during payment.
4. Once the order shows Paid, return to Cart and refresh. All original rows, including the
   same variant, should remain with their original quantities. A Buy Now payment consumes
   stock for its purchased quantity without removing saved cart rows.
5. Reopen My orders and refresh the paid order. Its item quantity and total should remain unchanged.

If this fails, record the order number and cart before/after. Verify that the checkout was
started using Buy Now in product details rather than Cart checkout.

## Unpaid expiry releases reserved stock

The local default reservation is 30 minutes from order creation. The app/backend use the actual
expiry returned by Xendit once the session is verified. The configured worker runs every minute;
release depends on verified provider expiry, not only a local countdown.

1. As admin, choose a quiet variant with Available at least 1 and Reserved = 0. Note its
   On hand and Available values. Avoid other purchases/stock edits for this variant during the test.
2. In the customer account, add quantity 1 to Cart, select it, and Place Order. Note the order number.
   Open Continue to Xendit to confirm that the test session exists, then close the tab without paying.
3. In admin Photos & stock, refresh. Expect On hand unchanged, Reserved = 1, and Available
   reduced by 1. My orders should still show Pending; closing the payment tab does not cancel it.
4. The pending Order details page shows **Payment deadline (local time)** using the saved
   session expiry. Wait until that time (normally about 30 minutes with the default
   configuration), then allow another 1–3 minutes for callback/worker processing. Refresh the
   existing order instead of creating another checkout. If Xendit returned a different expiry, use it.
5. Expect the order to show Expired, the original cart row to remain, On hand unchanged,
   Reserved = 0, and Available restored to its starting value.
6. Refresh the order and stock again. Values should remain stable and payment should never show Paid.

If Pending remains after provider expiry and the processing allowance, record the order number,
expiry time, payment label, stock values, and the latest reconcile-payments invocation status.
Do not edit payment state or release reservations manually to make the check pass. HTTP 200
from the dashboard's sample webhook alone does not verify expiry of this actual order.

## Customer account isolation

Use the same browser/app origin for sign-out and sign-in so this also checks that the previous
account's data is hidden immediately. Keep existing app/site data and finish active checkout first.

1. In account A, note one cart row, a saved address, and an existing order number.
2. Account → Sign out. Create/sign in to a new account B using a different email; confirm
   the email first if requested. Leave B as an ordinary customer without an admin role.
3. In B, Cart, saved addresses, and My orders should initially be empty. A's address,
   order number, and cart rows must not appear. Account must not show Admin panel.
4. Add a different cart item and a saved address identifiable as B's. No payment is needed.
5. Sign out B and sign back in as A. A's original cart/address/orders should still be there;
   B's new cart item/address should not appear.
6. Sign back in as B and check its own cart/address were persisted. If any private data crosses
   accounts, stop this checkpoint and record the affected screen and account transition.

These are app/device checks. Backend permission checks were run separately against the local
disposable PostgreSQL database; actual hosted isolation results require this user confirmation.

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
| Return page displays HTML source | Deploy the current plain-text `payment-return` bundle, JWT OFF; no SQL or new payment is needed. |
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
