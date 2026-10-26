# Flutter: login and catalog

Implemented locally: dark collection screen, Supabase initialization/session persistence,
email/password sign-in and signup, sign-out, current account/profile/role display,
catalog search/categories, product details, option selection, safe available-stock view,
loading/error/retry states, and image fallbacks. The display name `CH / COLLECTION`
is provisional. Seed products/prices remain fictional samples.

Cart, addresses, checkout/payment screens, orders, and admin management are next milestones.
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
They inject a fake gateway and never create real accounts or payments.

In the assistant environment, dependency resolution from the existing local package cache and
Dart analysis succeeded. The standard Flutter command cannot write the SDK cache lockfile
outside the allowed workspace, so widget tests and device/APK builds remain unrun.
An attempted public catalog read could not resolve the project hostname from this environment;
the app's hosted connection and credentials still require the device checks above.

If the collection fails, verify Internet access and the project URL/public key, then check
that the hosted SQL verification remains all OK. Do not disable RLS to fix a client error.
If login says Email not confirmed, complete that account's confirmation before retrying.
