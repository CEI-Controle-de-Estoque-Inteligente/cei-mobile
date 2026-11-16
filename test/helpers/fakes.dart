import 'dart:async';

import 'package:cei_mobile/core/errors/app_exception.dart';
import 'package:cei_mobile/data/models/empresa.dart';
import 'package:cei_mobile/data/models/perfil.dart';
import 'package:cei_mobile/data/models/produto.dart';
import 'package:cei_mobile/data/repositories/auth_repository.dart';

Perfil perfilFake({Cargo cargo = Cargo.gerente, bool ativo = true}) => Perfil(
  id: 'u1',
  empresaId: 'e1',
  nome: 'Maria Souza',
  email: 'maria@cei.com',
  cargo: cargo,
  turno: Turno.integral,
  status: StatusFuncionario.ativo,
  ativo: ativo,
  empresa: const Empresa(id: 'e1', nome: 'Mercado Teste', codigoConvite: 'ABC123'),
);

Produto produtoFake({
  String id = 'p1',
  int quantidade = 10,
  int minimo = 5,
  int maximo = 20,
  DateTime? validade,
  double preco = 10,
}) => Produto(
  id: id,
  empresaId: 'e1',
  nome: 'Produto $id',
  preco: preco,
  quantidade: quantidade,
  estoqueMinimo: minimo,
  estoqueMaximo: maximo,
  validade: validade,
);

/// AuthRepository falso para testar ViewModels sem rede.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.perfil, this.erroLogin});

  Perfil? perfil;
  AppException? erroLogin;
  final StreamController<String?> _controller = StreamController<String?>.broadcast();
  String? _usuarioId;
  int tentativasLogin = 0;

  @override
  Stream<String?> get usuarioMudou => _controller.stream;

  @override
  String? get usuarioAtualId => _usuarioId;

  @override
  Future<Perfil> carregarPerfil() async {
    final p = perfil;
    if (p == null) throw const AuthAppException('Sua sessão expirou. Entre novamente.');
    return p;
  }

  @override
  Future<void> entrar({required String email, required String senha}) async {
    tentativasLogin++;
    final erro = erroLogin;
    if (erro != null) throw erro;
    _usuarioId = perfil?.id ?? 'u1';
    _controller.add(_usuarioId);
  }

  @override
  Future<void> sair() async {
    _usuarioId = null;
    _controller.add(null);
  }

  @override
  Future<bool> cadastrar(DadosCadastro dados) async => false;

  @override
  Future<String?> nomeEmpresaPorCodigo(String codigo) async => codigo == 'ABC123' ? 'Mercado Teste' : null;

  @override
  Future<void> enviarCodigoRecuperacao(String email) async {}

  @override
  Future<void> redefinirSenha({required String email, required String codigo, required String novaSenha}) async {}

  @override
  Future<void> alterarSenha({required String senhaAtual, required String novaSenha}) async {}

  @override
  Future<void> atualizarNome(String nome) async {}

  Future<void> close() => _controller.close();
}
