import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';

/// Estado global de sessão. O roteador escuta este ViewModel para
/// proteger as rotas internas (C2.5).
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._authRepository);

  final AuthRepository _authRepository;

  bool get isAuthenticated => _authRepository.isAuthenticated;

  Future<void> signIn({required String email, required String password}) async {
    await _authRepository.signIn(email: email, password: password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authRepository.signOut();
    notifyListeners();
  }
}
