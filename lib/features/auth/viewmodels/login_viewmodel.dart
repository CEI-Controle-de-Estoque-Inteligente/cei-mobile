import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/repositories/auth_repository.dart';

/// Estado da tela de login: carregando / erro / sucesso (C1.6, C5.3).
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._auth);

  final AuthRepository _auth;

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    _notify();
  }

  /// Retorna `true` quando o login foi concluído. Em caso de sucesso, a
  /// sessão muda e o roteador leva o usuário para a tela inicial.
  Future<bool> submit({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      await _auth.entrar(email: email, senha: password);
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      _notify(); // O roteador pode ter descartado a tela neste ponto.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
