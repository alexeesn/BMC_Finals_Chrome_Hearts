# Project status

Last updated: 2026-10-25 (Asia/Singapore).

## Current phase

Step 1: persistent local project documentation. The user asked for `AGENTS.md` and supporting notes before app implementation. The user handles Git commits and pushes.

## Completed

- Discussed the school ecommerce concept, stack, shopping features, and admin panel.
- Inspected the user's existing local repository after file access became available.
- Identified the existing Flutter app in `ecommerce/`.
- Created root `AGENTS.md`, `PROJECT_PLAN.md`, this status file, and `docs/CLASS_REFERENCE.md`.
- Recorded the user's instruction to use their own project, without depending on the instructor's repository.

## Observed codebase

- `ecommerce/lib/main.dart` contains the Flutter starter counter application.
- `ecommerce/test/widget_test.dart` contains the starter counter widget test.
- `ecommerce/pubspec.yaml` has Flutter and `cupertino_icons` runtime dependencies; Supabase and payment packages have not been added.
- The app has Android, iOS, web, Windows, macOS, and Linux folders. Final delivery targets still need confirmation.
- Existing `ecommerce/README.md` is the starter README.
- Git status was clean before this documentation change.

No ecommerce app features or backend deployments have been implemented in this conversation. Installed Flutter tooling and account configuration have not been verified.

## Immediate next step

Plan the screen map and initial layouts with the user. Start with Home and Product Details, then Cart and Checkout, before finalizing the database.

Keep the one-store Android app, shared customer/admin app, fixed shipping fee, and black/white/silver theme as proposals until confirmed through discussion or an implementation request.

## Open decisions

- Final app/shop display name.
- Android-only delivery and whether the rubric requires a separate admin website.
- Sample products, images, categories, and applicable variants.
- Shipping fee and address-entry approach.
- Stock reservation, payment expiry, cancellation, and purchased-cart-item removal behavior.
- Any extra grading or presentation requirements.

Resolve questions at the relevant milestone instead of asking everything at once.

## Verification and environment

- Workspace: `C:\Users\teodo\OneDrive\Documents\BMC LOURENCE X XEESH`.
- Flutter app directory: `ecommerce/`.
- Earlier file-access failures were followed by successful local reads in the resumed session. They are historical, not a current blocker.
- Verified all four project documents exist, are nonempty, have headings, and their referenced local files exist. Git status showed only the new documentation paths after this change.
- Documentation-only work; no runtime tests or APK builds were needed or run.
- No credentials were requested, recorded, or verified.
- No commits, pushes, or deployments were performed.

## Handoff

Read `AGENTS.md`, this file, and `PROJECT_PLAN.md` before continuing. Follow the latest user instructions and update these notes after meaningful progress. Use session resume for the conversation history; these documents preserve the project decisions and current state.
