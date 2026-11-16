import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/perfil.dart';

/// Dados do cadastro: cria uma empresa (gerente) ou entra numa existente.
class DadosCadastro {
  const DadosCadastro({
    required this.nome,
    required this.email,
    required this.senha,
    this.empresaNome,
    this.cnpj,
    this.codigoEmpresa,
  });

  final String nome;
  final String email;
  final String senha;
  final String? empresaNome;
  final String? cnpj;
  final String? codigoEmpresa;

  bool get entrandoEmEmpresa => codigoEmpresa != null && codigoEmpresa!.isNotEmpty;
}

/// Contrato de autenticação. ViewModels dependem só desta abstração (C2.9),
/// o que permite testá-los com uma implementação falsa.
abstract interface class AuthRepository {
  /// Emite o id do usuário logado (ou null) sempre que a sessão muda.
  Stream<String?> get usuarioMudou;

  String? get usuarioAtualId;

  Future<Perfil> carregarPerfil();

  Future<void> entrar({required String email, required String senha});

  /// Retorna `true` se a conta precisa de confirmação por e-mail.
  Future<bool> cadastrar(DadosCadastro dados);

  Future<String?> nomeEmpresaPorCodigo(String codigo);

  Future<void> enviarCodigoRecuperacao(String email);

  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  });

  Future<void> alterarSenha({required String senhaAtual, required String novaSenha});

  Future<void> atualizarNome(String nome);

  Future<void> sair();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  static const Duration _timeout = Duration(seconds: 15);

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<String?> get usuarioMudou =>
      _auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  String? get usuarioAtualId => _auth.currentUser?.id;

  @override
  Future<Perfil> carregarPerfil() => _guard(() async {
    final id = usuarioAtualId;
    if (id == null) throw const AuthAppException('Sua sessão expirou. Entre novamente.');
    final row = await _client
        .from('perfis')
        .select('*, empresas(*)')
        .eq('id', id)
        .single()
        .timeout(_timeout);
    return Perfil.fromJson(row);
  });

  @override
  Future<void> entrar({required String email, required String senha}) => _guard(() async {
    await _auth.signInWithPassword(email: email.trim(), password: senha).timeout(_timeout);
  });

  @override
  Future<bool> cadastrar(DadosCadastro dados) => _guard(() async {
    final response = await _auth
        .signUp(
          email: dados.email.trim(),
          password: dados.senha,
          data: {
            'nome': dados.nome.trim(),
            if (dados.entrandoEmEmpresa) 'codigo_empresa': dados.codigoEmpresa!.trim().toUpperCase(),
            if (!dados.entrandoEmEmpresa) 'empresa_nome': dados.empresaNome?.trim(),
            if (!dados.entrandoEmEmpresa) 'cnpj': dados.cnpj,
          },
        )
        .timeout(_timeout);

    // Com "Confirm email" ativo, o Supabase devolve usuário sem identidades
    // quando o e-mail já existe (proteção contra enumeração de contas).
    final identities = response.user?.identities;
    if (response.user != null && identities != null && identities.isEmpty) {
      throw const AuthAppException('Este e-mail já está cadastrado.');
    }
    return response.session == null;
  });

  @override
  Future<String?> nomeEmpresaPorCodigo(String codigo) => _guard(() async {
    final nome = await _client
        .rpc<String?>('empresa_por_codigo', params: {'p_codigo': codigo.trim()})
        .timeout(_timeout);
    return nome;
  });

  @override
  Future<void> enviarCodigoRecuperacao(String email) => _guard(() async {
    await _auth.resetPasswordForEmail(email.trim()).timeout(_timeout);
  });

  @override
  Future<void> redefinirSenha({
    required String email,
    required String codigo,
    required String novaSenha,
  }) => _guard(() async {
    await _auth
        .verifyOTP(email: email.trim(), token: codigo.trim(), type: OtpType.recovery)
        .timeout(_timeout);
    await _auth.updateUser(UserAttributes(password: novaSenha)).timeout(_timeout);
  });

  @override
  Future<void> alterarSenha({required String senhaAtual, required String novaSenha}) =>
      _guard(() async {
        final email = _auth.currentUser?.email;
        if (email == null) throw const AuthAppException('Sua sessão expirou. Entre novamente.');
        // Reautentica para confirmar que é o próprio usuário.
        try {
          await _auth.signInWithPassword(email: email, password: senhaAtual).timeout(_timeout);
        } on AuthException {
          throw const AuthAppException('Senha atual incorreta.');
        }
        await _auth.updateUser(UserAttributes(password: novaSenha)).timeout(_timeout);
      });

  @override
  Future<void> atualizarNome(String nome) => _guard(() async {
    await _client.rpc<dynamic>('atualizar_meu_nome', params: {'p_nome': nome.trim()}).timeout(_timeout);
  });

  @override
  Future<void> sair() => _guard(() => _auth.signOut());

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
