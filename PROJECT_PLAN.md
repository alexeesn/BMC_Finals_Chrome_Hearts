# Ecommerce project plan

## Purpose

Build a functional school ecommerce app with a Chrome Hearts product catalog, using the user's existing Flutter project. The intended purchase demo covers browsing, cart or Buy Now, delivery address selection, checkout, Xendit test payment, and order history. Include an admin panel.

## Confirmed requirements

| Area | Requirement |
| --- | --- |
| Purpose | School project with working shopping flows |
| Frontend | Flutter |
| Backend | Supabase |
| Payment provider | Xendit |
| Catalog concept | Chrome Hearts products |
| Visual direction | Dark theme with black/charcoal surfaces, silver accents, and light text |
| Shopping | Working Add to Cart and Buy Now |
| Delivery details | Saved customer addresses and checkout |
| Administration | Include an admin panel |
| Codebase | User's own local project; Flutter app is in `ecommerce/` |
| Git workflow | User handles commits and pushes |

## Proposed baseline

These are planning defaults, not additional confirmed requirements:

- Android APK as the primary deliverable, following the class handout. Other Flutter platform folders already exist; their presence does not establish delivery requirements.
- One store, with customer and admin roles in the same Flutter app.
- Xendit Test Mode for presentation payments.
- Prominent product photos and Gothic-inspired display typography within the confirmed dark theme; final font and images are still to be selected.
- Categories such as jewelry, clothing, eyewear, and accessories; finalize the actual sample catalog and variants before seeding.
- A fixed shipping fee calculated by the backend; the amount is undecided.
- Order history and admin-managed fulfillment status for the school demo.

## Customer screens

| Screen | Planned behavior |
| --- | --- |
| Register / Login | Create an account, sign in/out, and retain the session |
| Home | Browse featured products and open product details |
| Categories / Search | Find products by category or text |
| Product Details | Images, description, price, stock, applicable variants, and quantity |
| Cart | Save items per customer, edit quantity, remove items, and select checkout items |
| My Addresses | Add, edit, delete, and choose a default delivery address |
| Checkout | Review items, select an address, view shipping and total, and start payment |
| Payment | Hosted Xendit payment page and refresh of the backend order state on return |
| My Orders / Order Details | Order history, purchased items, delivery snapshot, totals, and statuses |
| Account | Profile, orders, addresses, and sign out |

Proposed main navigation: Home, Categories, Cart, Account.

Detailed proposed layouts and screen states: [Screen plan](docs/SCREEN_PLAN.md).
Offline interactive design preview: [Shopping flow](docs/previews/shopping-flow.html).
These artifacts use fictional data for review; the Flutter app has not been implemented from them yet.

### Shopping behavior

- Add to Cart persists the selected variant and quantity in the customer's Supabase cart.
- Cart checkout uses selected items and preserves unselected items.
- Buy Now opens checkout for the selected item without changing the existing cart.
- Address fields: recipient name, phone, province, city/municipality, barangay, street/building/unit, postal code, optional delivery instructions, and default flag.
- Validate address ownership and required fields. Save a delivery-address snapshot on each order.
- Decide structured geographical dropdowns versus validated text fields during screen planning.
- Define when purchased cart items are removed as part of the checkout/payment policy.

## Admin screens

- Dashboard with basic product and order counts.
- Product list and add/edit form.
- Product image uploads through Supabase Storage.
- Category and applicable product variant management.
- Stock management per sellable variant.
- Order list/details and allowed fulfillment updates, initially Preparing → Shipped → Delivered.

Admin access must be provisioned through a trusted process and enforced on the backend.

## Backend architecture

| Component | Responsibility |
| --- | --- |
| Supabase Auth | Accounts, sessions, and identity |
| Supabase Postgres | Catalog, roles, customer data, cart, orders, and payment records |
| Supabase Storage | Product images |
| Supabase Edge Functions | Trusted checkout/invoice operations and webhook processing |
| Xendit | Hosted payment and asynchronous test payment updates |

### Proposed database entities

- Profiles and trusted role assignments.
- Categories, products, and ordered product images.
- Product variants: sellable combinations, SKU, price, and stock.
- Customer addresses and cart items.
- Orders: customer, totals, delivery snapshot, payment and fulfillment states.
- Order items: immutable purchased item/variant/price snapshots.
- Payments: order link, Xendit reference, amount/currency, and state.

Finalize constraints, ownership policies, role provisioning, and inventory strategy before migrations. Supabase Auth manages credentials; do not create a separate password table.

### Checkout/payment flow

1. Authenticate customer and validate address ownership.
2. Backend validates active products/variants, quantities, current prices, and stock.
3. Calculate totals and create or reuse a pending order safely.
4. Create a Xendit test invoice/payment associated with that order.
5. Flutter opens the hosted payment URL.
6. Webhook validates its token, payment reference, expected amount/currency, and relevant status.
7. Apply the payment transition once and follow the agreed stock policy.
8. Flutter fetches the current order state; navigation alone is not payment confirmation.

The class function names are `create-invoice` and `xendit-webhook`. They can be retained if the final integration uses that workflow; verify current provider support during implementation.

Candidate payment states: Pending, Paid, Expired, Failed. Keep fulfillment separate: Preparing, Shipped, Delivered after payment confirmation. Confirm exact provider mappings and transitions when implementing.

Handle closed payment pages, interrupted requests/retries, pending/expired payments, repeated callbacks, and concurrent checkout attempts. Decide stock reservation, release, and cancellation eligibility before adding related controls.

## Milestones

1. Project documentation and handoff notes.
2. Screen map and layouts, including sample product/variant needs.
3. Database design, permissions, role provisioning, stock policy, and payment transitions.
4. Existing Flutter app foundation, authentication, and catalog.
5. Persistent cart, Buy Now, addresses, and server-validated checkout.
6. Xendit payment integration and order history.
7. Admin catalog, image, stock, and fulfillment management.
8. End-to-end validation and release APK.

## Verification targets for implementation

- Customer A cannot read or modify Customer B's private records.
- Customers cannot perform admin operations or elevate their role.
- Cart persists; Buy Now preserves the existing cart.
- Backend rejects tampered prices and invalid stock/quantity selections.
- Verified test payments update only the matching order.
- Invalid/mismatched callbacks do not mark orders paid.
- Duplicate callbacks/retries do not duplicate order/payment/inventory effects.
- Pending/expired payments follow the documented stock policy.
- Later catalog/address edits do not rewrite past order snapshots.
- Admin fulfillment updates appear in customer order details.
- Appropriate Flutter analysis/tests pass and the release APK builds.

## Deferred scope

Multiple sellers, courier APIs, live-money payments, chat, vouchers, reviews, and push notifications are outside the initial proposal unless requested or required by the rubric.
