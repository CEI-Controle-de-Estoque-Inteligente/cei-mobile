import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

class PerfilViewModel extends ChangeNotifier {
  PerfilViewModel(this._auth, this._session);

  final AuthRepository _auth;
  final SessionViewModel _session;

  bool _salvando = false;
  String? _erro;
  bool _disposed = false;

  bool get salvando => _salvando;
  String? get erro => _erro;

  Future<bool> atualizarNome(String nome) => _executar(() async {
    await _auth.atualizarNome(nome);
    await _session.recarregarPerfil();
  });

  Future<bool> alterarSenha({required String atual, required String nova}) =>
      _executar(() => _auth.alterarSenha(senhaAtual: atual, novaSenha: nova));

  Future<void> sair() => _session.sair();

  Future<bool> _executar(Future<void> Function() acao) async {
    _salvando = true;
    _erro = null;
    _notify();
    try {
      await acao();
      return true;
    } on AppException catch (e) {
      _erro = e.message;
      return false;
    } finally {
      _salvando = false;
      _notify();
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
