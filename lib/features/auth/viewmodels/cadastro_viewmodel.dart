import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/remote/brasil_api_service.dart';
import '../../../data/repositories/auth_repository.dart';

enum ModoCadastro { novaEmpresa, entrarEmEmpresa }

enum ResultadoCadastro { logado, confirmarEmail, erro }

class CadastroViewModel extends ChangeNotifier {
  CadastroViewModel(this._auth, this._brasilApi);

  final AuthRepository _auth;
  final BrasilApiService _brasilApi;

  ModoCadastro _modo = ModoCadastro.novaEmpresa;
  bool _salvando = false;
  bool _consultandoCnpj = false;
  bool _verificandoCodigo = false;
  bool _obscure = true;
  String? _erro;
  String? _empresaDoCodigo;
  bool _disposed = false;

  ModoCadastro get modo => _modo;
  bool get salvando => _salvando;
  bool get consultandoCnpj => _consultandoCnpj;
  bool get verificandoCodigo => _verificandoCodigo;
  bool get obscure => _obscure;
  String? get erro => _erro;

  /// Nome da empresa encontrada pelo código (confirmação visual).
  String? get empresaDoCodigo => _empresaDoCodigo;

  void alterarModo(ModoCadastro modo) {
    _modo = modo;
    _erro = null;
    _notify();
  }

  void alternarSenha() {
    _obscure = !_obscure;
    _notify();
  }

  void codigoAlterado() {
    if (_empresaDoCodigo == null) return;
    _empresaDoCodigo = null;
    _notify();
  }

  /// Consulta a BrasilAPI e devolve o nome sugerido para a empresa.
  Future<String?> consultarCnpj(String cnpj) async {
    _consultandoCnpj = true;
    _erro = null;
    _notify();
    try {
      final empresa = await _brasilApi.consultarCnpj(Formatters.onlyDigits(cnpj));
      return empresa.nomeExibicao;
    } on AppException catch (e) {
      _erro = e.message;
      return null;
    } finally {
      _consultandoCnpj = false;
      _notify();
    }
  }

  Future<void> verificarCodigo(String codigo) async {
    _verificandoCodigo = true;
    _erro = null;
    _notify();
    try {
      final nome = await _auth.nomeEmpresaPorCodigo(codigo);
      _empresaDoCodigo = nome;
      if (nome == null) _erro = 'Nenhuma empresa encontrada com este código.';
    } on AppException catch (e) {
      _erro = e.message;
    } finally {
      _verificandoCodigo = false;
      _notify();
    }
  }

  Future<ResultadoCadastro> cadastrar(DadosCadastro dados) async {
    _salvando = true;
    _erro = null;
    _notify();
    try {
      if (dados.entrandoEmEmpresa) {
        final nome = await _auth.nomeEmpresaPorCodigo(dados.codigoEmpresa!);
        if (nome == null) {
          _erro = 'Código de empresa inválido. Peça o código ao gerente.';
          return ResultadoCadastro.erro;
        }
      }
      final precisaConfirmar = await _auth.cadastrar(dados);
      return precisaConfirmar ? ResultadoCadastro.confirmarEmail : ResultadoCadastro.logado;
    } on AppException catch (e) {
      _erro = e.message;
      return ResultadoCadastro.erro;
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
