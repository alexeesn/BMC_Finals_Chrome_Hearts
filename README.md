# CuHss / CH Collection

School ecommerce app built with Flutter, Supabase, and Xendit Test Mode. Features
include product browsing and search, customer accounts, cart, Buy Now, delivery
addresses, checkout, order history, and admin catalog, stock, and delivery management.
The Flutter app is in `ecommerce/`.

## Requirements

| Requirement | Purpose |
| --- | --- |
| Flutter stable with Dart **3.13.4 or newer, below 4.0** | App dependencies; see `ecommerce/pubspec.yaml` |
| Microsoft Edge or Chrome | Browser demo on Windows |
| Android Studio, Android SDK, and a compatible JDK | Android emulator/device and APK builds |
| Internet access and an accessible Supabase project | Accounts, products, cart, addresses, and orders |
| Configured Supabase backend and Xendit Test Mode integration | Order placement and payment updates |

Local SDK observed: Flutter **3.47.8**, Dart **3.13.7**. Use this version or a
compatible stable SDK. The Android Gradle configuration uses Java/JVM target 17;
use a JDK compatible with the checked-in Gradle and Android Gradle Plugin versions.
Install reference: [Flutter installation](https://docs.flutter.dev/install).

Open PowerShell in the repository root:

```powershell
cd ecommerce
flutter --version
flutter doctor
```

Resolve any requirements reported for your target platform. For Android, complete
the SDK setup and accept the licenses with `flutter doctor --android-licenses`.

## 1. Configure the environment

Local public app configuration is stored in `ecommerce/.env`. For a fresh checkout
without an existing `.env`, run this from `ecommerce/`:

```powershell
Copy-Item .env.example .env
```

If `.env` already exists, edit the existing file. Use this format:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLIC_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Get the Project URL and publishable key from the **same Supabase project**, using
the project's **Connect** dialog or **Settings → API Keys**. The intended legacy
`anon` public key is also supported if that is what the existing project uses.
Keep Xendit secrets, webhook tokens, database passwords, and Supabase secret or
service-role keys out of this file. App configuration is included in the compiled
app; `.env` does not hide secrets. [Supabase key reference](https://supabase.com/docs/guides/getting-started/api-keys).

The local `.env` prepared in this workspace contains the previous public app
configuration. **Dashboard access to that Supabase project is still unresolved.**
Confirm access to the intended project before expecting hosted data, login, or
payments to work. The `.env.example` file contains placeholders for other developers.

The app already reads `SUPABASE_URL` and `SUPABASE_PUBLIC_KEY` using
`String.fromEnvironment` in `ecommerce/lib/config/app_config.dart`. Flutter passes
the `.env` values when you use `--dart-define-from-file=.env`. No dotenv package
or `.env` asset is required. A plain `flutter run` uses the previous fallback
values in `app_config.dart`; it does not automatically read `.env`.
After editing `.env`, stop and run the app again; hot reload is not sufficient.

Git ignores `.env` and `.env.*`; `.env.example` is the template intended for version control.

## 2. Install dependencies and run in Edge

Run all Flutter commands in this guide from `ecommerce/`:

```powershell
flutter pub get
flutter run -d edge --web-port 63594 --dart-define-from-file=.env
```

Browser URL: `http://localhost:63594`. This is the project's existing Edge origin.
For Chrome, keep the same port and replace `-d edge` with `-d chrome`.
Use the same browser/origin when recovering an unfinished checkout; browser
sessions and recovery hints are stored per origin.

For web checkout, the Supabase Edge Function secret `APP_ORIGINS` must allow the
exact origin `http://localhost:63594`, without a trailing slash. This is a backend
setting, rather than an additional app `.env` variable. Follow the
[payment setup/checkpoints](docs/PAYMENT_TEST.md) if it is not configured yet.

## 3. Run on Android

1. Start an emulator, or connect an Android phone over USB and enable USB debugging.
2. Accept the USB debugging prompt on the phone.
3. Find the device ID:

   ```powershell
   flutter devices
   ```

4. Replace `YOUR_DEVICE_ID` with the actual ID and run:

   ```powershell
   flutter run -d YOUR_DEVICE_ID --dart-define-from-file=.env
   ```

Supabase uses a hosted HTTPS URL, so the phone does not need your laptop's IP
address. Hosted payment opens in the device browser. The app already includes
the Android Internet permission.

## 4. Build and install the demo APK

Once the Android SDK, environment configuration, and backend are ready:

```powershell
flutter pub get
flutter build apk --release --dart-define-from-file=.env
```

Expected output, relative to `ecommerce/`:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Copy the APK to the Android phone and open it. If Android prompts you, allow
installation from your trusted file manager or browser. Tap **Install**, then
open **CuHss**. Updating an existing installation requires a compatible package
and signature. If there is a conflict, resolve any unfinished checkout before
considering an uninstall.

The phone does not need a separate `.env` file: public configuration is included
in the built APK. After changing the Supabase configuration, rebuild and reinstall.

The current release build configuration uses **debug signing** for the school demo.
Production signing and Play Store preparation require separate work. The assistant
has not verified an APK build or phone installation during this documentation update.
[Flutter Android build reference](https://docs.flutter.dev/deployment/android).

## Backend prerequisites and first login

Installing the app does not create Supabase tables, Auth users, admin roles, or
Edge Functions. Use the existing backend if it is already working. For a new
Supabase project, follow the [dashboard setup guide](docs/SUPABASE_XENDIT_SETUP.md)
one stage at a time, including migrations 0001–0006, permissions, and functions.
Do not rerun the initial schema on a project that already has these tables.

The app uses the existing Xendit Test Mode integration. App installation does not
change the Xendit dashboard. Switching to another Supabase project changes the
function/webhook URL; review the backend connection using the setup guide.

1. Open Account → Register, or sign in with an existing **app account**. App login
   is separate from Supabase dashboard login. Confirm the email if required by the
   Auth settings.
2. Check the catalog, Add to Cart, and saved address. Purchases require catalog
   records and available variants.
3. For admin access, follow the [admin setup](docs/ADMIN_SETUP.md). The admin role
   is assigned through trusted owner SQL; customer signup does not grant it.
4. For an optional dummy purchase and delivery status demo, follow the
   [purchase-record guide](docs/PURCHASE_RECORDS.md). This creates a sample Paid
   record without an actual Xendit payment.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| `flutter` is not recognized | Flutter SDK installation/PATH, then reopen the terminal |
| Dependency SDK constraint error | `flutter --version`; project requires Dart 3.13.4 or compatible 3.x |
| `.env` not found | Run from `ecommerce/`; the filename must be `.env`, not `.env.txt` |
| Environment edits do not appear | Stop app and rerun with `--dart-define-from-file=.env` |
| Supabase initialization/catalog/login fails | Valid URL/public key from the same accessible project; Internet and hosted setup |
| Dashboard says “You don't have access” | Verify the dashboard project/organization/session; this alone does not prove data deletion |
| Table Editor/Auth Users empty | Confirm intended project before rerunning schema or creating replacement accounts |
| `Email not confirmed` | Complete the account's confirmation email |
| Place Order shows HTTP 0 in browser | Exact browser origin in `APP_ORIGINS`; check Network/Edge logs and My orders before retrying |
| No admin panel | Login with the already-provisioned admin account; inspect trusted role setup |
| No Android device | `flutter devices`, USB debugging/authorization, emulator, and `flutter doctor` |
| SDK cache `lockfile` permission error | Run from your normal user terminal with a writable Flutter installation; it is not a Supabase table error |

## Verification commands

From `ecommerce/`:

```powershell
flutter analyze
flutter test
dart run test/order_model_checks.dart
dart run test/admin_model_checks.dart
```

These are commands for the installer/developer to run. Latest actual check results,
remaining device/payment/access issues, and release limits are in [PROJECT_STATUS.md](PROJECT_STATUS.md).
Additional screen checks: [Flutter setup](docs/FLUTTER_SETUP.md),
[UI review](docs/UI_REVIEW.md), and [backend package](supabase/README.md).
