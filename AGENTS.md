# Project instructions

## Read first

At the start of a work session, read:

1. `PROJECT_STATUS.md` for progress, verification, open decisions, and the next step.
2. `PROJECT_PLAN.md` for requirements, proposed screens, architecture, and milestones.
3. `docs/CLASS_REFERENCE.md` when working on the class payment/backend integration.

The user's latest instructions take priority. Distinguish confirmed requirements, proposals, and implemented behavior. These documents preserve project context, not the full conversation transcript.

## Workspace

- This repository belongs to the user. Use its existing local code as the source of truth.
- The Flutter app is in `ecommerce/`; run Flutter commands from that directory.
- Keep shared planning documents at the repository root.
- Do not clone or use the instructor's repository as the application base. The class handout is an integration reference only.
- Inspect existing files before changing them. Preserve user changes and do not scaffold another Flutter app over the existing one.
- The user handles Git commits and pushes. Make local changes and report them; do not commit or push unless explicitly asked.

## Product and communication

- School ecommerce project using Flutter, Supabase, and Xendit.
- Chrome Hearts is the product catalog concept.
- The user selected a dark theme: black/charcoal surfaces, silver accents, light readable text, and a Gothic-inspired visual direction.
- Required: working Add to Cart, Buy Now, delivery addresses, checkout, and an admin panel.
- Communicate in clear, friendly Taglish unless requested otherwise.
- Explain choices simply and keep the presentation/demo in mind.
- Follow the current phase in `PROJECT_STATUS.md`. Do not treat a planned milestone as authorization to implement the entire app.
- Continue routine, reversible work within the user's requested scope without repeated confirmation.
- Check available context before asking questions. Resolve open decisions when they affect the current milestone.
- Do not create external accounts, incur charges, or deploy merely because the handout describes those steps.

## Implementation rules for later phases

- Use Xendit Test Mode for the school demo unless the user changes that scope.
- Keep Xendit secrets, webhook verification tokens, and privileged Supabase keys on the backend. Never embed them in Flutter, commit them, or print their values.
- Flutter may use the intended Supabase public/client key and project URL. Protect private data with authentication and Row Level Security.
- Enforce admin permissions on the backend. Customer signup and profile updates must not allow customers to grant themselves admin privileges.
- Customers may access only their own private profile, cart, addresses, orders, and payment details.
- Calculate checkout prices, shipping, and totals on the backend. Validate active variants, quantities, and available stock there.
- Store purchased item, variant, unit price, and delivery-address snapshots so later catalog/profile edits do not change past orders.
- Keep payment status separate from fulfillment status.
- Authenticate invoice creation and verify the customer's order ownership.
- Verify the webhook token, matching payment/order, expected amount/currency, and allowed status transition.
- Handle repeated callbacks and checkout retries without duplicate orders, payment effects, or stock changes.
- Never mark an order paid solely because the payment page closes or navigates to a success URL.
- Decide and document stock reservation, payment expiry, and cancellation behavior before implementing payment-related inventory changes.
- Use HTTPS for hosted services. Do not enable global Android cleartext traffic simply because the class example includes it.
- Check current official documentation when implementing packages and APIs. Finalize the schema and policies before writing migrations.
- Run checks appropriate to the change. Distinguish unrun checks from passing checks; documentation-only changes do not require an APK build.

## Maintain the handoff

After meaningful work, update `PROJECT_STATUS.md` with completed work, actual verification, blockers, and the next concrete step. Update `PROJECT_PLAN.md` when requirements or architecture decisions change. Never record credentials in project notes.
