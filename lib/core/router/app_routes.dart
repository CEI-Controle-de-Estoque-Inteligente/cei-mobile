/// Caminhos centralizados das rotas (C2.2).
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String settings = '/home/settings';

  /// Rotas acessíveis sem autenticação.
  static const Set<String> public = {splash, login};
}
