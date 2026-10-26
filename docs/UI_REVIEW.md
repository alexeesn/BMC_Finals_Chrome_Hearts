# Customer UI review

The Flutter customer screens now share a charcoal/silver theme, serif headings, outlined panels,
consistent buttons, and bounded content widths. This is implemented in `ecommerce/lib/`;
the original HTML preview remains a separate design reference.

## Open the updated app

The user supplied four lifestyle photos in `ecommerce/asset/img/` for the Collection banner.
These are now registered in pubspec.yaml. Fully stop Flutter with **q**, then run from
`ecommerce/` so the asset bundle is rebuilt. Keep the same Edge origin and browser/site data:

```powershell
flutter pub get
flutter run -d edge --web-port 63594
```

No new dependency, SQL, or Edge Function update is required. The pub get/restart refreshes
the project configuration and bundled images.

## Screens to review

| Screen | Changes to inspect |
| --- | --- |
| Collection | Four-photo lookbook banner cycling every 5 seconds, swipe/arrows/dots/pause controls, serif headline, search, category chips, larger product imagery, sold-out badges, and responsive 1–4 column cards. |
| Product details | Square gallery and thumbnails, category/name/price hierarchy, option panel, quantity control, and a fixed Add to cart/Buy Now bar. Image/details sit side by side on wide screens. |
| Cart | Selected cards outlined in silver, larger thumbnails, saved-item count, fixed selected subtotal/Checkout, and a collection shortcut in the empty state. |
| Checkout | Review heading, delivery/selection/summary panels, readable item totals, desktop summary column, and a fixed Place Order button. |
| Account | Personal-archive header, signed-in identity panel, order/address links, profile/role panel, conditional admin entry, and sign-out action. |
| My orders | Flexible order cards, local dates, paid delivery progress, and pending payment deadlines from the earlier tracking pass. |

Review at a narrow phone width (about 360–390 px) and a wide browser width. Product names,
addresses, email, and totals should stay readable. With larger system/browser text, quantity
controls and action buttons should remain usable; product actions stack when space is tight.
Check the existing loading, signed-out, empty, and error states too.

Product photos come from existing Supabase catalog uploads. Missing images use the existing
placeholder. The display name remains `CH / COLLECTION` and typography uses a system serif;
no final custom Gothic font is bundled. The banner uses the four supplied JPGs as local assets;
product cards/details continue to use catalog uploads. The original photo files are preserved.

On Collection, leave the banner idle for more than 5 seconds and verify the next photo appears.
Swipe or use dots/arrows to select a photo, then check autoplay resumes. Pause/play controls
let the user stop/restart it. Autoplay stops while another main tab/route is shown or the app
is in the background, and respects the device's reduced-animation setting. In reduced-animation
mode, manual navigation remains available. On desktop, portraits fit beside the banner copy;
on phones, photos fill the banner with text over a dark gradient, moving below for larger text.

## Verification

Source formatting and whole-app Dart analysis are checked locally. Widget/browser rendering
has not been executed by the assistant because Flutter's SDK cache lockfile is outside its
writable workspace and no browser control tool is available. Actual layout and shopping behavior
still require the user's app review. The SDK restriction applies to assistant tooling; the user
can continue running Flutter normally in their own terminal.

The user previously reported cart/stock, customer isolation, Buy Now cart preservation, paid
payment, and fulfillment checks successful. Unpaid expiry remains explicitly unconfirmed;
follow [payment checkpoints](PAYMENT_TEST.md) using the existing unpaid order after its deadline.
