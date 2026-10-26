# CH / Collection — school ecommerce

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

From this folder:

```powershell
flutter pub get
flutter run
```

See [Flutter setup and checkpoints](../docs/FLUTTER_SETUP.md) for configuration,
manual account checks, tests, and current verification limits.
