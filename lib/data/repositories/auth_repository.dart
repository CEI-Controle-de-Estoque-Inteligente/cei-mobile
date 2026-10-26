/// Contrato de autenticação. A UI e os ViewModels dependem apenas desta
/// abstração; a implementação concreta (Supabase Auth) entra na Sprint 1.
abstract interface class AuthRepository {
  bool get isAuthenticated;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Exceção de domínio com mensagem amigável (nunca exibir erro técnico - C1.6).
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Implementação PRELIMINAR da Sprint 0 (dados locais, sem backend).
/// Será substituída por `SupabaseAuthRepository` na Sprint 1 — issue [C2.4].
class PreliminaryAuthRepository implements AuthRepository {
  bool _authenticated = false;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _authenticated = true;
  }

  @override
  Future<void> signOut() async {
    _authenticated = false;
  }
}
