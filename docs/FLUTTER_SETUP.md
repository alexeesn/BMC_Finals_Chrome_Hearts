# Flutter: login and catalog

Implemented locally: dark collection screen, Supabase initialization/session persistence,
email/password sign-in and signup, sign-out, current account/profile/role display,
catalog search/categories, product details, option selection, safe available-stock view,
loading/error/retry states, and image fallbacks. The display name `CH / COLLECTION`
is provisional. Seed products/prices remain fictional samples.

Persistent cart and saved delivery addresses are also implemented locally. Buy Now,
checkout/payment screens, orders, and admin management are next milestones.
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

Cart subtotals are a review display. The trusted checkout will calculate final prices, shipping,
and stock eligibility; the cart does not reserve stock. Buy Now/checkout and payment controls
are not part of this cart/address checkpoint.

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
They inject a fake gateway and never create real accounts or payments.

In the assistant environment, dependency resolution from the existing local package cache and
Dart analysis succeeded. The standard Flutter command cannot write the SDK cache lockfile
outside the allowed workspace, so widget tests and device/APK builds remain unrun.
An attempted public catalog read could not resolve the project hostname from this environment;
the app's hosted connection and credentials still require the device checks above.

If the collection fails, verify Internet access and the project URL/public key, then check
that the hosted SQL verification remains all OK. Do not disable RLS to fix a client error.
If login says Email not confirmed, complete that account's confirmation before retrying.
