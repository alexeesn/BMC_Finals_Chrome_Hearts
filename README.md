# CuHss / CH Collection

School ecommerce app gamit ang Flutter, Supabase, at Xendit Test Mode. May product
catalog/search, customer accounts, cart, Buy Now, delivery addresses, checkout,
order history, at admin catalog/stock/delivery management. Nasa `ecommerce/` ang app.

## Requirements

| Kailangan | Para saan |
| --- | --- |
| Flutter stable na may Dart **3.13.4 or newer, below 4.0** | App dependencies; tingnan ang `ecommerce/pubspec.yaml` |
| Microsoft Edge o Chrome | Browser demo sa Windows |
| Android Studio, Android SDK, at compatible JDK | Android emulator/device at APK builds |
| Internet at accessible na Supabase project | Accounts, products, cart, addresses, at orders |
| Existing Supabase backend at Xendit Test Mode setup | Place Order at payment updates |

Local SDK observed: Flutter **3.47.8**, Dart **3.13.7**. Para pareho ang setup,
gamitin ang version na ito o compatible stable SDK. Android Gradle config uses
Java/JVM target 17; gamitin ang JDK na compatible sa checked-in Gradle/AGP versions.
Install reference: [Flutter installation](https://docs.flutter.dev/install).

Mula sa repository root, buksan ang PowerShell:

```powershell
cd ecommerce
flutter --version
flutter doctor
```

Ayusin ang reported requirements para sa target na gagamitin. Para sa Android,
complete din ang SDK setup/licenses gamit ang `flutter doctor --android-licenses`.

## 1. I-configure ang environment

Nasa `ecommerce/.env` ang local public app configuration. Para sa bagong kopya ng
repository na wala pang `.env`, gawin ito mula sa `ecommerce/`:

```powershell
Copy-Item .env.example .env
```

Kung may `.env` na, i-edit na lang ang existing file. Format:

```dotenv
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLIC_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Kunin ang Project URL at publishable key mula sa **parehong Supabase project**:
project **Connect** dialog o **Settings → API Keys**. Supported din ang intended
legacy `anon` public key kung iyon ang existing project configuration.
Huwag ilagay rito ang Xendit secret, webhook token, database password, o Supabase
secret/service-role key. App config is included in the compiled app; `.env` does
not hide secrets. [Supabase key reference](https://supabase.com/docs/guides/getting-started/api-keys).

Ang local `.env` na inihanda sa workspace ay galing sa dating public app config.
**Unresolved pa ang dashboard access sa dating Supabase project.** Kailangan munang
ma-confirm ang accessible project bago asahang gumana ang hosted data/login/payment.
Ang `.env.example` ay placeholders lang para sa ibang developer.

The app already reads `SUPABASE_URL` and `SUPABASE_PUBLIC_KEY` using
`String.fromEnvironment` in `ecommerce/lib/config/app_config.dart`. Ipapasa ng
Flutter ang `.env` values kapag may `--dart-define-from-file=.env`. Walang dotenv
package o `.env` asset na kailangang idagdag. Kapag plain `flutter run` lang, ang
dating values sa `app_config.dart` ang fallback; hindi awtomatikong binabasa ang `.env`.
Kapag nag-edit ng `.env`, stop at run ulit; hindi sapat ang hot reload.

Git ignores `.env` at `.env.*`; `.env.example` lang ang template na puwedeng i-track.

## 2. Install dependencies at patakbuhin sa Edge

Lahat ng Flutter commands sa guide ay mula sa `ecommerce/`:

```powershell
flutter pub get
flutter run -d edge --web-port 63594 --dart-define-from-file=.env
```

Browser URL: `http://localhost:63594`. Ito ang existing Edge origin ng project.
Para sa Chrome, gamitin ang parehong port at `-d chrome` sa halip na `-d edge`.
Use the same browser/origin when recovering an unfinished checkout; browser
sessions at recovery hints are stored per origin.

Para sa web checkout, dapat allowed ang exact origin na `http://localhost:63594`
sa Supabase Edge Function secret na `APP_ORIGINS`. Walang trailing slash.
Backend setting ito, hindi dagdag na variable sa app `.env`.
Sundan ang [payment setup/checkpoints](docs/PAYMENT_TEST.md) kung hindi pa configured.

## 3. Patakbuhin sa Android

1. Buksan ang emulator, o ikabit ang Android phone gamit ang USB at enable USB debugging.
2. Accept ang USB debugging prompt sa phone.
3. Hanapin ang device ID:

   ```powershell
   flutter devices
   ```

4. Palitan ang `YOUR_DEVICE_ID` at run:

   ```powershell
   flutter run -d YOUR_DEVICE_ID --dart-define-from-file=.env
   ```

Ang Supabase URL ay hosted HTTPS URL; walang kailangang laptop IP sa phone.
Hosted payment opens sa device browser. May Android Internet permission na sa app.

## 4. Gumawa at mag-install ng demo APK

Pag ready na ang Android SDK at valid na ang environment/backend:

```powershell
flutter pub get
flutter build apk --release --dart-define-from-file=.env
```

Expected output, relative sa `ecommerce/`:

```text
build/app/outputs/flutter-apk/app-release.apk
```

I-copy ang APK sa Android phone, buksan, at payagan ang installation mula sa trusted
file manager/browser kung hihingin ng Android. Tap **Install**, tapos buksan ang
**CuHss**. Kung update ng existing installation, dapat compatible ang package/signature;
kapag may conflict, huwag agad mag-uninstall habang may unfinished checkout.

Hindi kailangan ng hiwalay na `.env` file sa phone: nasa built APK na ang public config.
Kapag nagpalit ng Supabase config, kailangang mag-build at mag-install ulit.

Current release build config uses **debug signing** para sa school demo. Production
signing at Play Store preparation are separate work. Walang APK build o phone
installation na na-verify ng assistant sa installation-documentation update na ito.
[Flutter Android build reference](https://docs.flutter.dev/deployment/android).

## Backend prerequisites at unang login

Installing the app does not create Supabase tables, Auth users, admin roles, or
Edge Functions. Kung existing at gumagana na ang backend, gamitin iyon. Para sa
bagong Supabase project, sundan ang [dashboard setup guide](docs/SUPABASE_XENDIT_SETUP.md)
one stage at a time, kasama ang migrations 0001–0006, permissions, at functions.
Huwag i-rerun ang initial schema sa project na may existing tables.

Gumagamit ng existing Xendit Test Mode integration ang app. App installation does
not change the Xendit dashboard. Kung ibang Supabase project ang gagamitin, mag-iiba
ang function/webhook URL; kailangang suriin ang backend connection gamit ang setup guide.

1. Account → Register, o mag-login gamit ang existing **app account**. Hiwalay ang app
   login sa Supabase dashboard login. Confirm the email kung required ng Auth settings.
2. Check ang catalog, Add to Cart, at saved address. Kailangan ng catalog records at
   available variants para makabili.
3. Para sa admin, sundan ang [admin setup](docs/ADMIN_SETUP.md). Trusted owner SQL
   ang nagbibigay ng admin role; hindi sapat ang customer signup.
4. Para sa optional dummy purchase at delivery-status demo, sundan ang
   [purchase-record guide](docs/PURCHASE_RECORDS.md). Sample Paid record iyon,
   walang actual Xendit payment.

## Troubleshooting

| Problema | I-check |
| --- | --- |
| `flutter` is not recognized | Flutter SDK installation/PATH, then reopen the terminal |
| Dependency SDK constraint error | `flutter --version`; project requires Dart 3.13.4 or compatible 3.x |
| `.env` not found | Run from `ecommerce/`; filename must be `.env`, hindi `.env.txt` |
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
remaining device/payment/access issues, at release limits are in [PROJECT_STATUS.md](PROJECT_STATUS.md).
Additional screen checks: [Flutter setup](docs/FLUTTER_SETUP.md),
[UI review](docs/UI_REVIEW.md), at [backend package](supabase/README.md).
