/// Exceções de domínio do app. Sempre carregam uma mensagem amigável,
/// pronta para ser exibida ao usuário (nunca um erro técnico - C1.6).
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sem internet ou servidor inacessível.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Sem conexão com a internet. Verifique sua rede e tente novamente.',
  ]);
}

/// O servidor demorou demais para responder.
class TimeoutAppException extends AppException {
  const TimeoutAppException([
    super.message = 'O servidor demorou para responder. Tente novamente.',
  ]);
}

/// Usuário autenticado, mas sem permissão para a ação.
class PermissionException extends AppException {
  const PermissionException([
    super.message = 'Você não tem permissão para realizar esta ação.',
  ]);
}

/// Sessão expirada ou credenciais inválidas.
class AuthAppException extends AppException {
  const AuthAppException(super.message);
}

/// Resposta inesperada (ex.: JSON inválido).
class DataFormatException extends AppException {
  const DataFormatException([
    super.message = 'Recebemos dados inválidos do servidor. Tente novamente mais tarde.',
  ]);
}
