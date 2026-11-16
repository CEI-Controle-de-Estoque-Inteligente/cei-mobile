/// Configuração lida em tempo de build via --dart-define-from-file=.env
/// (as chaves NUNCA ficam no código nem no repositório - C5.5).
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
