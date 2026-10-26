# Customer UI review

The Flutter customer screens now share a charcoal/silver theme, serif headings, outlined panels,
consistent buttons, and bounded content widths. This is implemented in `ecommerce/lib/`;
the accepted [HTML prototype](previews/shopping-flow.html) is the layout reference. The latest
correction restores its navigation, header, content order, cards, and footer structure.

## Open the updated app

The user supplied four lifestyle photos in `ecommerce/asset/img/` for the Collection banner.
These are registered in pubspec.yaml. For the current layout correction, press capital **R**
in the Flutter terminal for a hot restart. If the earlier photo assets have not been bundled yet,
fully stop with **q**, then run from `ecommerce/`. Keep the same Edge origin and browser/site data:

```powershell
flutter pub get
flutter run -d edge --web-port 63594
```

No new dependency, SQL, or Edge Function update is required. The pub get/restart refreshes
the project configuration and bundled images.

## Screens to review

| Screen | Changes to inspect |
| --- | --- |
| Home | Brand plus tagline at left; circular cart/count at right. Find your next piece/search, then the automatic photo banner, horizontal category pills, and The edit. Flat product cards follow the HTML, with responsive columns on wide screens. |
| Bottom navigation | Home, Categories, Cart, Account with muted outline icons and silver selected text. Categories scrolls to and focuses the category chips. Cart opens its full layout; its header returns to shopping. |
| Product details | Back/The details/cart-count header, 1.15-ratio image gallery, category/name alongside price, rectangular option controls, bordered quantity stepper, description, and fixed Add to cart/Buy Now actions. Wide-screen image/details layout is preserved. |
| Cart | Back/Your cart/item-count header, separated rows with 72×84 thumbnails, checkboxes, quantity steppers, and Remove. Shipping note follows the rows. Selected subtotal and Checkout are beside each other, stacking for narrow/large-text layouts. |
| Checkout | Back/Checkout/Review header, delivery/selection/summary panels, readable totals, and Total to pay beside Place Order. The action keeps the existing trusted checkout flow; it does not mark an order paid. |
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
on phones, compact copy and portraits sit beside each other as in the prototype's hero layout,
moving into a column for larger text. Browse collection scrolls to The edit.

Check the top cart count after adding/changing/removing an item. Both Home and product-header
cart buttons must open the same saved cart. Test all four navigation items, Categories scrolling,
Cart's Continue shopping button, and system back from a main section. The shell keeps one cart
controller and preserves account/data ownership checks.

## Verification

Source formatting and whole-app Dart analysis are checked locally. The existing quote test
expectation now accounts for the same canonical total in both summary and footer. Widget/browser rendering
has not been executed by the assistant because Flutter's SDK cache lockfile is outside its
writable workspace and no browser control tool is available. Actual layout and shopping behavior
still require the user's app review. The SDK restriction applies to assistant tooling; the user
can continue running Flutter normally in their own terminal.

The user previously reported cart/stock, customer isolation, Buy Now cart preservation, paid
payment, and fulfillment checks successful. Unpaid expiry remains explicitly unconfirmed;
follow [payment checkpoints](PAYMENT_TEST.md) using the existing unpaid order after its deadline.
