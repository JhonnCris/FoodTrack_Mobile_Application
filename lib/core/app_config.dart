class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static String get supabaseConfigurationError {
    if (supabaseUrl.isEmpty && supabaseAnonKey.isEmpty) {
      return 'Supabase is not configured.';
    }
    if (supabaseUrl.isEmpty) {
      return 'SUPABASE_URL is missing.';
    }
    return 'SUPABASE_ANON_KEY is missing.';
  }
}
