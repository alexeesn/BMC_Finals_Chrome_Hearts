# Admin panel: setup and demo

The admin panel is part of the existing dark Flutter app: Account → Admin panel.
It uses the signed-in account's server-assigned admin role. No service-role/Xendit key
is embedded in Flutter and there is no customer-facing role editor.

## Setup

1. Keep the existing tables, catalog, paid orders, roles, secrets, and functions.
2. Supabase → SQL Editor → New Query: paste the complete contents of
   [0006_admin_variant_concurrency.sql](../supabase/migrations/0006_admin_variant_concurrency.sql), then Run.
   This adds an admin-only stock/price save wrapper. It adds no tables or products.
   Do not rerun 0001–0005 or the seed.
3. From `ecommerce/`, run `flutter pub get` if you have not already done so. The new
   `file_selector` dependency handles native/browser file selection. It is already present
   in the local package config observed during implementation.
4. Fully stop/restart the app so the new plugin is registered. For the user's existing Edge origin:

```powershell
flutter run -d edge --web-port 63594
```

   This retains the origin already allowed in APP_ORIGINS. For an Android device/emulator,
   use `flutter run` and select Android. The assistant has not built an APK or verified the
   native picker in this environment.
5. Sign in with the account already promoted to admin. Open Account → Admin panel.
   A normal customer should not see this entry and is denied by the guard/backend if reached.

## Products, categories, images, and stock

1. Overview shows exact database counts for products, orders, paid orders, and pending orders.
   Use Refresh overview after making store changes.
2. Catalog → Categories: add/edit a category with a unique lowercase hyphenated slug, active
   flag, and display order. Archiving a category hides its products from shoppers.
3. Catalog → Products → Add product: use **Choose photo** to select an optional cover photo
   and see its preview, then enter name, unique slug, category, and description. The photo uploads
   when Save is pressed, after product metadata is saved. New products default to draft.
   Add variants before publishing. Edit product has the same cover-photo control.
4. Manage product → Add variant: enter a unique SKU, option/size, PHP price, and stock on hand.
   Price input uses exact centavos, not a floating-point total. Quantity/stock must be whole numbers.
5. Stock on hand includes reserved items. Available stock is on hand minus reserved.
   The backend refuses stock below reservations. The checked save also refuses a form whose
   variant changed since it was loaded, including changes from checkout/reservation/payment.
   Go back and reopen the variant form after a stale-data warning.
6. For an existing product, use **Photos & stock** in the catalog list, then **Upload image**
   for additional images or **Replace image**. Pick a JPEG, PNG, or WebP up to 5 MB. The app checks size/signature and the
   existing Storage bucket enforces MIME/size/admin insertion. The first image is the cover;
   multiple images can be viewed in the customer product gallery.
7. Replace image uploads to a new unique object path and updates that image's catalog row.
   It never overwrites/deletes the previous object, so image paths saved on old orders remain valid.
   If upload succeeds but metadata saving fails, a public orphaned object can remain for owner
   cleanup; the app does not delete objects or automatically retry an uncertain upload.
   If a cover-photo upload fails while saving Add/Edit product, the product stays saved and a
   message directs you to Photos & stock to inspect/retry the photo without creating another product.
   If the picker reports it is not loaded, fully stop/restart Flutter to register the plugin.
8. Edit details / visibility → Published when ready. Ensure the category and at least one
   variant are active. Publishing without an available active variant leaves no purchasable option.
9. Leave the admin panel. The shopping catalog and cart reload so names, images, prices, and stock
   reflect the edits. Existing purchased item/address snapshots stay unchanged.

Catalog management currently reads up to 1,000 categories/products/variants, suitable for this school
demo. Exact overview counts are separate database counts. Larger catalogs need listing pagination.
Archive catalog records instead of hard deleting products or order-linked files.

## Orders and fulfillment

Kung wala pang order records, puwedeng gamitin ang owner-only
[dummy purchase seed](PURCHASE_RECORDS.md). May `DEMO` order na Paid/Preparing para
sa status demo, walang actual payment o pagbabago sa catalog/cart/stock.

1. Admin panel → Orders shows store orders with payment filters and 30-row pagination.
2. Open an order to inspect purchased item/address snapshots, final total, payment status, and
   fulfillment status. Admin details do not offer a customer payment button or manual Mark Paid.
3. A paid order in Preparing can be marked Shipped, then Delivered. The backend enforces
   paid-only forward transitions and safely accepts a repeated identical status.
4. Open that order from the customer's My orders and refresh. The fulfillment update should appear.
5. Pending, expired, cancelled, and needs-review orders have no fulfillment action. Payment status
   remains governed by verified Xendit processing and the reconciliation worker.

### Current demo checkpoint: Shipped → Delivered

Use the existing Paid test order and note its order number. No new payment or SQL is needed.

1. Account → Admin panel → Orders → set Payment status to **Paid**.
2. Open that order number. Expect payment **Paid** and fulfillment `preparing`.
3. Tap **Mark as shipped**. Expect `Fulfillment: shipped` while payment stays **Paid**.
4. Return to Account → My orders → open the same order → tap the top-right refresh icon.
   Expect **Shipped** as the current stage in Delivery progress. For another customer's order,
   check it using that customer's account.
5. Return to the admin order → tap **Mark as delivered**. Expect `Fulfillment: delivered`.
6. Refresh the same customer order again. Expect **Delivered** completed and payment **Paid**.
   The delivered admin order should no longer offer a next fulfillment action.

If the expected button is absent, inspect the payment and fulfillment labels first. An already
delivered order has completed this flow. If saving fails, keep the order number and exact error
message for diagnosis. Actual hosted fulfillment results remain pending user confirmation.

## Verification

```powershell
flutter analyze
flutter test
dart run test/admin_model_checks.dart
```

The local database suite passed fresh migrations, admin/customer permissions, archive visibility,
order snapshot preservation, customer-visible fulfillment, and cross-transaction stale stock checks
after both reservation and payment. It also runs the original checkout/stock/concurrency/security
tests and 30 Edge handler tests. The standalone Dart admin checks and Dart analysis pass.

Widget tests cover customer denial, account-switch hiding, and paid forward fulfillment; they are
authored/analyzed but cannot start here because the Flutter SDK cache lockfile is outside the
assistant's writable workspace. Actual hosted 0006 deployment, admin UI, picker, Storage upload,
and Android release build still need the user's device/dashboard checks above.
