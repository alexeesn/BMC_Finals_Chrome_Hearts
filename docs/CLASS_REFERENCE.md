# Class integration reference

## Scope

The user supplied an instructor setup guide during planning. Use its Supabase/Xendit workflow as a reference while building on the user's own local project in `ecommerce/`.

The instructor's repository is not a project dependency. Do not clone it, replace the user's app with it, or assume its file structure is required.

The pasted guide omitted actual SQL, Edge Function bodies, and some screenshots/Android snippets. Those sections have not been reviewed as code or installed.

For our current project walkthrough, read [Supabase + Xendit setup](SUPABASE_XENDIT_SETUP.md) and [database plan](DATABASE_PLAN.md). Current Xendit documentation distinguishes Payment Sessions from the handout's legacy invoice flow; our local package implements test Payment Sessions through `create-payment`, with account access still to be verified. The class names below describe the supplied handout. The user prefers the same dashboard copy/paste workflow; local TypeScript files are simply the source of the code pasted into Edge Functions.

## Supabase setup described in the handout

- Create or sign into an account at https://supabase.com.
- Exercise organization: `BMC`.
- Exercise project: `BMC-ecom1`.
- Run supplied SQL/permissions through SQL Editor.
- Add backend secrets through Edge Functions → Secrets.
- Deploy Edge Functions using the dashboard editor.

These resource names are assignment references, not proof that they exist. Confirm actual project configuration and current service limits when relevant.

## Xendit setup described in the handout

- Registration: https://dashboard.xendit.co/register/1.
- Use Test Mode / Development for the demo.
- Generate a secret key with the payment-collection permissions needed by the chosen API.
- Store `XENDIT_SECRET_KEY` and `XENDIT_WEBHOOK_TOKEN` as Supabase Edge Function Secrets.
- Payout/Money-Out permissions are unnecessary unless a separately requested feature needs them.
- Never store these secrets in Flutter, Git, or project notes.

## Edge Functions described in the handout

### `create-invoice`

Creates a hosted Xendit invoice. For the expanded app, authenticate the customer, verify order ownership, and use backend-calculated totals.

### `xendit-webhook`

Receives external Xendit notifications. The handout disables Supabase JWT verification for this endpoint and checks incoming `x-callback-token` against `XENDIT_WEBHOOK_TOKEN` inside the handler.

Endpoint shape:

```text
https://<project-ref>.supabase.co/functions/v1/xendit-webhook
```

The guide connects this endpoint to invoice-paid webhook settings and uses Test and Save. Verify current dashboard/API behavior during implementation.

The webhook setting does not remove customer authentication requirements from invoice creation. Match callbacks to expected payment/order/amount and process repeated notifications safely.

## Flutter and Android reference

The handout creates a sample Flutter app and installs `supabase_flutter` and `webview_flutter`. Our local Flutter app already exists in `ecommerce/`; inspect it and choose dependencies during implementation rather than scaffolding another app.

Its sample config names are `supabaseUrl` and `supabaseAnonKey`. Use the intended public/client credentials for the actual project and SDK. Never substitute a privileged backend key.

Add Android internet permission for hosted service access. The handout mentions `android:usesCleartextTraffic="true"`; hosted HTTPS services do not require enabling global cleartext traffic. Scope any local-development exception to an actual need.

Release build, run from `ecommerce/` when implementation is ready:

```powershell
flutter build apk --release
```

## References for implementation

- Supabase Flutter: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- Edge Function secrets: https://supabase.com/docs/guides/functions/secrets
- Edge Function authentication: https://supabase.com/docs/guides/functions/auth
- Xendit test mode: https://help.xendit.co/hc/en-us/articles/360025424692-What-can-I-do-in-Test-Development-Mode
- Xendit webhooks: https://docs.xendit.co/v1/docs/handling-webhooks

Read current official documentation when coding. These references do not certify compatibility of an integration that has not yet been implemented.
