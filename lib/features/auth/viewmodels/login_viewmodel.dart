import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import 'session_viewmodel.dart';

/// Estado da tela de login: carregando / erro / sucesso (C1.6, C5.3).
class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._session);

  final SessionViewModel _session;

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get obscurePassword => _obscurePassword;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  /// Retorna `true` quando o login foi concluído com sucesso.
  Future<bool> submit({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _session.signIn(email: email.trim(), password: password);
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Não foi possível entrar agora. Tente novamente.';
      return false;
    } finally {
      _isLoading = false;
      // O roteador pode descartar esta tela logo após o login.
      if (!_disposed) notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
