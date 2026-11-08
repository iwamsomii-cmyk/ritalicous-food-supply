/// Supabase public settings are supplied at BUILD time (GitHub secrets):
///   --dart-define=SUPABASE_URL=...  --dart-define=SUPABASE_PUBLISHABLE_KEY=...
/// Never put a Supabase secret / service_role key inside the app.
class CloudConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get configured =>
      url.trim().startsWith('https://') && publishableKey.trim().isNotEmpty;
}
