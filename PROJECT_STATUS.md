# Project status

Last updated: 2026-10-25 (Asia/Singapore).

## Current phase

Step 2: screen map and layout proposal, following the user's request to proceed after project documentation. The user handles Git commits and pushes. Flutter implementation has not started.

## Completed

- Discussed the school ecommerce concept, stack, shopping features, and admin panel.
- Inspected the user's existing local repository after file access became available.
- Identified the existing Flutter app in `ecommerce/`.
- Created root `AGENTS.md`, `PROJECT_PLAN.md`, this status file, and `docs/CLASS_REFERENCE.md`.
- Recorded the user's instruction to use their own project, without depending on the instructor's repository.
- Prepared `docs/SCREEN_PLAN.md` with the customer/admin navigation map, four detailed shopping screen layouts, authentication proposal, and loading/empty/error states.
- Created `docs/previews/shopping-flow.html`, an offline interactive visual proposal for Home, Product Details, Cart, and Checkout. It uses fictional browser-memory data and makes no backend/payment calls.
- Applied the user's dark-theme request throughout the preview: black/charcoal backgrounds, silver primary controls, light text, dark dialogs, and Gothic-inspired display typography. Dark theme is now a confirmed design requirement.

## Observed codebase

- `ecommerce/lib/main.dart` contains the Flutter starter counter application.
- `ecommerce/test/widget_test.dart` contains the starter counter widget test.
- `ecommerce/pubspec.yaml` has Flutter and `cupertino_icons` runtime dependencies; Supabase and payment packages have not been added.
- The app has Android, iOS, web, Windows, macOS, and Linux folders. Final delivery targets still need confirmation.
- Existing `ecommerce/README.md` is the starter README.
- Git status was clean before this documentation change.

No ecommerce app features or backend deployments have been implemented in this conversation. Installed Flutter tooling and account configuration have not been verified.

## Immediate next step

Review the screen/layout proposal with the user using `docs/previews/shopping-flow.html` and incorporate feedback. Once the design direction is settled, prepare the database/schema and permissions plan, including stock/payment policies, before implementing app features.

Keep the one-store Android app, shared customer/admin app, and fixed shipping fee as proposals until confirmed through discussion or an implementation request. The user has confirmed the dark-theme direction; the final font, shop name, and product imagery remain open.

## Open decisions

- Final app/shop display name.
- Android-only delivery and whether the rubric requires a separate admin website.
- Sample products, images, categories, and applicable variants.
- Feedback on the four-screen visual proposal and navigation; `CH / COLLECTION` is only a preview label.
- Shipping fee and address-entry approach.
- Stock reservation, payment expiry, cancellation, and purchased-cart-item removal behavior.
- Any extra grading or presentation requirements.

Resolve questions at the relevant milestone instead of asking everything at once.

## Verification and environment

- Workspace: `C:\Users\teodo\OneDrive\Documents\BMC LOURENCE X XEESH`.
- Flutter app directory: `ecommerce/`.
- Earlier file-access failures were followed by successful local reads in the resumed session. They are historical, not a current blocker.
- Verified all four project documents exist, are nonempty, have headings, and their referenced local files exist. Git status showed only the new documentation paths after this change.
- Screen-preview verification passed: JavaScript syntax, unique HTML IDs, referenced elements/SVGs, all four screen containers, standalone asset structure, and the local preview link. `git diff --check` passed; Git emitted only line-ending conversion notices.
- Dark-theme checks passed: no remaining white surface rules; JavaScript syntax and SVG/ID structure remain valid. Five main text/background contrast pairs measured 7.23:1 to 16.69:1. These token checks do not replace visual browser review.
- Headless Edge could not start its GPU process in this environment. Browser interaction checks and visual/responsive rendering could not be completed; review the HTML in a normal browser. Do not claim those checks passed.
- `git status --short -- ecommerce` showed no Flutter app changes. No Flutter analysis/tests or APK builds were run for this planning task.
- No credentials were requested, recorded, or verified.
- No commits, pushes, or deployments were performed.

## Handoff

Read `AGENTS.md`, this file, and `PROJECT_PLAN.md` before continuing. Follow the latest user instructions and update these notes after meaningful progress. Use session resume for the conversation history; these documents preserve the project decisions and current state.
