/// Public client configuration. RLS protects private customer data.
/// Never put Xendit, service_role, or sb_secret_ keys in the app.
/// Prefer --dart-define-from-file=.env (see the installation README).
/// The saved defaults below are legacy fallbacks; project access is unverified.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pxxendicdpkdjuhidiur.supabase.co',
  );
  static const supabasePublicKey = String.fromEnvironment(
    'SUPABASE_PUBLIC_KEY',
    defaultValue: 'sb_publishable_qmk-xHwcNJnlEEcb019n2A_lTFihD5G',
  );
}
