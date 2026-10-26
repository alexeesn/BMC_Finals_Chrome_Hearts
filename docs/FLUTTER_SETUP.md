# Flutter: login and catalog

Implemented locally: dark collection screen, Supabase initialization/session persistence,
email/password sign-in and signup, sign-out, current account/profile/role display,
catalog search/categories, product details, option selection, safe available-stock view,
loading/error/retry states, and image fallbacks. The display name `CH / COLLECTION`
is provisional. Seed products/prices remain fictional samples.

Persistent cart, saved delivery addresses, Buy Now, and checkout review are implemented locally.
Place Order, canonical order details, external hosted test payment, and My orders are implemented locally.
Follow [Payment setup and demo checkpoints](PAYMENT_TEST.md) before submitting the first test order.
Real provider/browser verification and admin management remain pending.
An admin role label does not imply that admin management screens are implemented.

## Run on your computer

1. Open a terminal in `ecommerce/`, the existing Flutter app folder.
2. Run:

```powershell
flutter pub get
flutter run
```

3. Choose a connected Android device/emulator, or Chrome if offered for an initial UI check.
4. The collection should load Archive Tee, Silver Band, and Everyday Cap from Supabase.
   Images show a fallback until product image records and Storage files exist.
5. Open a product. Select an available option and verify its price/stock. Sold-out options
   cannot be selected. Pull to refresh the catalog to retrieve current stock/prices.
6. Open Account → Sign in / Register. Use the **app account** created under Supabase Auth,
   not your Supabase dashboard password. Your promoted account should show Admin account.
7. Restart the app and confirm the session remains. Sign out and confirm the account data clears.
8. Create a separate customer via the registration form. If email confirmation is enabled,
   open the confirmation email, then return to the app and sign in. It should show Customer account.
   Automatic opening of the installed app from email links is not configured in this milestone.

## Cart and address checkpoint

After this update, hot restart the app (`R` in an active `flutter run` terminal), or run it again.
No additional SQL or package installation is needed for cart/addresses.

1. Open a product, select an available option, choose a quantity, and tap Add to cart.
   If signed out, sign in first; returning to the product resumes the add action.
2. Add the same option again. It should merge into one cart row without exceeding the current
   stock or 99 items. The app checks availability; only a later backend checkout reserves stock.
3. Open Cart. Change quantity, select/unselect rows, check the selected subtotal, and remove a row.
   Refresh the cart when stock changes. An archived/unavailable variant remains removable.
4. Restart the app and verify the cart remains for the same account. Sign out, then use a second
   customer and verify their cart is separate. Late reads from the previous account must not
   repopulate the current cart. Concurrent edits return a refresh message instead of overwriting
   a changed revision.
5. Open Account → My addresses → Add address. Fill in recipient, phone, province, city,
   barangay, street, and four-digit Philippine postal code; instructions are optional.
   This milestone uses validated text fields rather than a geographic-directory API.
6. Save, edit, and choose Set as default. The default operation uses the existing
   `set_default_address` RPC; normal address edits never directly write the default flag.
7. Restart and verify addresses/default remain. Test a second account for isolation.
8. Delete an address and confirm it disappears. Deleting the default can leave no default;
   an upcoming checkout must still require an explicit valid address.

Cart subtotals are a review display. The checkout review reads prices/shipping/stock from the
backend; the actual order/payment operation will validate again. Cart and review do not reserve stock.

## Buy Now and checkout review checkpoint

1. In Supabase SQL Editor → New Query, paste the complete contents of
   [0005_checkout_quote.sql](../supabase/migrations/0005_checkout_quote.sql) and Run.
   This adds one authenticated read-only RPC. It does not add tables, seed products,
   change existing policies, or create orders. Do not rerun 0001–0004.
2. Hot restart the Flutter app (`R`), or run it again. No new dependencies were added.
3. Product → choose an available option/quantity → Buy Now. Sign in if needed.
4. Choose an owned saved address. If none exists, use Add / edit addresses, save one,
   and return; the review reloads your list. Current/default address is selected initially.
5. Check product, option, quantity, shipping, and total. The database supplies all amounts.
   The demo fee is PHP 150 only while the hosted setting remains unchanged.
6. Return to Cart: Buy Now must preserve saved cart rows/quantities.
7. Select some cart rows → Checkout. Only the selected IDs are quoted; the backend obtains
   their saved quantities. Unselected rows remain. At most 20 different lines per review.
8. Switch address or refresh checkout and confirm the quote reloads. An unavailable item,
   insufficient stock, or deleted address should stop the review with a useful error.
9. Reaching this screen must not create an order/payment, reserve stock, or clear the cart.

Place Order is now available after the quote. Before using it, follow
[Payment setup and demo checkpoints](PAYMENT_TEST.md), including current deployed bundles and browser origins.
The existing Edge backend remains the payment authority; no new SQL is needed for payment UI.

## Public configuration

`lib/config/app_config.dart` contains the user-supplied project URL and public publishable key.
These are client configuration, not server secrets. No Xendit keys or privileged database
keys are included. You can override them at launch:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLIC_KEY=YOUR_PUBLIC_KEY
```

Keep RLS enabled. Account role display reads the signed-in user's `user_roles` record;
the backend enforces admin permissions. Android release Internet permission is included;
hosted requests use HTTPS.

## Checks

```powershell
flutter analyze
flutter test
```

Widget tests cover catalog filtering, sold-out option selection, retry after a failed fetch,
form validation, login/logout and account switching, and signup requiring email confirmation.
Additional tests cover cart merging/reopening, quantity/removal UI, stale cart reads after logout,
rejected cart mutations, and address validation/saving. They remain unrun under the SDK restriction.
Checkout tests additionally cover Buy Now preserving the cart, requiring an address before a quote,
and selected-cart-only request payloads. Placeholder tests cover 64×76, 160×160, and 320×280
at text scales 1/2/3; these Flutter tests are authored/analyzed but remain unrun here.
They inject a fake gateway and never create real accounts or payments.

In the assistant environment, dependency resolution from the existing local package cache and
Dart analysis succeeded. The standard Flutter command cannot write the SDK cache lockfile
outside the allowed workspace, so widget tests and device/APK builds remain unrun.
An attempted public catalog read could not resolve the project hostname from this environment;
the app's hosted connection and credentials still require the device checks above.

If the collection fails, verify Internet access and the project URL/public key, then check
that the hosted SQL verification remains all OK. Do not disable RLS to fix a client error.
If login says Email not confirmed, complete that account's confirmation before retrying.
