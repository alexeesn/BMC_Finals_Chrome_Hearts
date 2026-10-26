# CH / Collection — app installation

Complete installation, environment, browser/Android, APK, and troubleshooting steps:
**[Repository installation README](../README.md)**.

For a fresh checkout without `.env`, copy `.env.example` to `.env` and fill in the
public Supabase URL/key from the same accessible project. Do not overwrite an
existing `.env`. The local workspace `.env` retains the previous public configuration;
access to that Supabase project is currently unresolved.

From this folder:

```powershell
flutter pub get
flutter run -d edge --web-port 63594 --dart-define-from-file=.env
```

For an Android phone/emulator, obtain its ID with `flutter devices`, then:

```powershell
flutter run -d YOUR_DEVICE_ID --dart-define-from-file=.env
```

School-demo APK build:

```powershell
flutter build apk --release --dart-define-from-file=.env
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Current release config uses
debug signing; APK/device validation remains pending. No `.env` file is needed on
the installed phone. Stop/run or rebuild after changing compile-time configuration.

## Implemented features

Existing Flutter app using Supabase Auth and catalog data, with the accepted dark theme.
Current milestone: collection/search, product details/options, login/register, sessions,
account role display, persistent cart, saved delivery addresses, Buy Now, and checkout review.
Apply `supabase/migrations/0005_checkout_quote.sql` before testing checkout review.
Place Order, external Xendit test payment, and My orders are also implemented locally.
Follow [payment setup/checkpoints](../docs/PAYMENT_TEST.md) before your first test payment.
The admin panel is implemented locally; apply migration 0006 and follow
[admin setup/checkpoints](../docs/ADMIN_SETUP.md) for catalog/images/stock and fulfillment.
Hosted/device admin verification and release validation remain pending.

The Collection, Product details, Cart, Checkout, and Account screens now have a shared
black/silver visual pass. See [customer UI review](../docs/UI_REVIEW.md) for opening the
updated Flutter app and reviewing the layouts before APK preparation.

See [Flutter setup and checkpoints](../docs/FLUTTER_SETUP.md) for configuration,
manual account checks, tests, and current verification limits.
