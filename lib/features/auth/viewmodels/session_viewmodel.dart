import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/local/preferences_service.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';

enum SessionStatus { carregando, deslogado, logado, erro }

/// Estado global da sessão. O roteador escuta este ViewModel para proteger
/// rotas e aplicar as permissões por cargo (C2.5).
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(
    this._auth,
    this._preferences, {
    Future<void> Function()? limparDadosLocais,
  }) : _limparDadosLocais = limparDadosLocais;

  final AuthRepository _auth;
  final PreferencesService _preferences;
  final Future<void> Function()? _limparDadosLocais;

  StreamSubscription<String?>? _subscription;
  SessionStatus _status = SessionStatus.carregando;
  Perfil? _perfil;
  String? _erro;
  String? _aviso;
  bool _recuperandoSenha = false;
  bool _disposed = false;

  SessionStatus get status => _status;
  Perfil? get perfil => _perfil;
  String? get erro => _erro;
  bool get isAuthenticated => _status == SessionStatus.logado && _perfil != null;
  bool get recuperandoSenha => _recuperandoSenha;

  /// Mensagem para exibir na tela de login (ex.: acesso desativado).
  String? consumirAviso() {
    final aviso = _aviso;
    _aviso = null;
    return aviso;
  }

  bool pode(Modulo modulo) => _perfil?.pode(modulo) ?? false;

  void start() {
    _subscription ??= _auth.usuarioMudou.listen(_onUsuario);
    if (_auth.usuarioAtualId == null && _status == SessionStatus.carregando) {
      // Sem sessão salva: o stream pode demorar a emitir.
      _setStatus(SessionStatus.deslogado);
    }
  }

  Future<void> _onUsuario(String? usuarioId) async {
    if (usuarioId == null) {
      _perfil = null;
      _setStatus(SessionStatus.deslogado);
      return;
    }
    if (_perfil?.id == usuarioId && _status == SessionStatus.logado) return;
    await recarregarPerfil();
  }

  Future<void> recarregarPerfil() async {
    if (_perfil == null) _setStatus(SessionStatus.carregando);
    try {
      final perfil = await _auth.carregarPerfil();
      if (!perfil.ativo) {
        _aviso = 'Seu acesso foi desativado pelo gerente da empresa.';
        await sair();
        return;
      }
      _perfil = perfil;
      _erro = null;
      await _preferences.savePerfilCache(perfil.toCacheJson());
      _setStatus(SessionStatus.logado);
    } on NetworkException catch (e) {
      _usarPerfilEmCache(e.message);
    } on TimeoutAppException catch (e) {
      _usarPerfilEmCache(e.message);
    } on AuthAppException catch (e) {
      _aviso = e.message;
      await sair();
    } on AppException catch (e) {
      _erro = e.message;
      _setStatus(SessionStatus.erro);
    }
  }

  /// Sem internet: abre o app com o último perfil conhecido (C4.4).
  void _usarPerfilEmCache(String mensagem) {
    final cache = _preferences.readPerfilCache();
    final usuarioId = _auth.usuarioAtualId;
    if (cache != null && cache['id'] == usuarioId) {
      _perfil = Perfil.fromJson(cache);
      _setStatus(SessionStatus.logado);
      return;
    }
    if (_perfil != null) return;
    _erro = mensagem;
    _setStatus(SessionStatus.erro);
  }

  void iniciarRecuperacaoSenha() => _recuperandoSenha = true;

  void concluirRecuperacaoSenha() {
    _recuperandoSenha = false;
    notifyListeners();
  }

  Future<void> sair() async {
    try {
      await _limparDadosLocais?.call();
      await _preferences.clearPerfilCache();
      await _auth.sair();
    } on AppException {
      // Mesmo sem conexão, a sessão local é encerrada.
    } finally {
      _perfil = null;
      _setStatus(SessionStatus.deslogado);
    }
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
