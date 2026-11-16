import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/repositories/auth_repository.dart';
import 'session_viewmodel.dart';

enum EtapaRecuperacao { email, codigo }

/// Recuperação de senha por código enviado ao e-mail (sem deep links).
class RecuperacaoViewModel extends ChangeNotifier {
  RecuperacaoViewModel(this._auth, this._session);

  final AuthRepository _auth;
  final SessionViewModel _session;

  EtapaRecuperacao _etapa = EtapaRecuperacao.email;
  bool _carregando = false;
  String? _erro;
  String _email = '';
  bool _disposed = false;

  EtapaRecuperacao get etapa => _etapa;
  bool get carregando => _carregando;
  String? get erro => _erro;
  String get email => _email;

  Future<bool> enviarCodigo(String email) async {
    return _executar(() async {
      await _auth.enviarCodigoRecuperacao(email);
      _email = email.trim();
      _etapa = EtapaRecuperacao.codigo;
    });
  }

  Future<bool> redefinir({required String codigo, required String novaSenha}) async {
    _session.iniciarRecuperacaoSenha();
    final ok = await _executar(
      () => _auth.redefinirSenha(email: _email, codigo: codigo, novaSenha: novaSenha),
    );
    _session.concluirRecuperacaoSenha();
    return ok;
  }

  void voltarParaEmail() {
    _etapa = EtapaRecuperacao.email;
    _erro = null;
    _notify();
  }

  Future<bool> _executar(Future<void> Function() acao) async {
    _carregando = true;
    _erro = null;
    _notify();
    try {
      await acao();
      return true;
    } on AppException catch (e) {
      _erro = e.message;
      return false;
    } finally {
      _carregando = false;
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
