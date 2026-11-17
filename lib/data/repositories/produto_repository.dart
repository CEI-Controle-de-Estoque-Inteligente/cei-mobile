import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/utils/id_generator.dart';
import '../local/pendencias_local_datasource.dart';
import '../local/produto_local_datasource.dart';
import '../models/movimentacao.dart';
import '../models/operacao_pendente.dart';
import '../models/produto.dart';
import '../remote/supabase_produto_datasource.dart';
import 'resultados.dart';

export '../remote/supabase_produto_datasource.dart' show FiltroEstoque;

abstract interface class ProdutoRepository {
  Future<Pagina<Produto>> listar({
    required String empresaId,
    String busca = '',
    FiltroEstoque filtro = FiltroEstoque.todos,
    int pagina = 0,
    int tamanho = 20,
  });

  Future<Produto> buscarPorId(String id);

  Future<Produto?> buscarPorCodigo(String empresaId, String codigo);

  Future<Produto> criar(Produto produto);

  Future<Produto> atualizar(Produto produto);

  Future<void> excluir(Produto produto);

  Future<void> restaurar(Produto produto);

  Future<ResultadoOperacao<Produto>> movimentar({
    required Produto produto,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  });

  Future<Pagina<Movimentacao>> historico(String produtoId, {int pagina = 0, int tamanho = 20});

  /// Aplica (1 a 90%) ou encerra (0) a promoção do produto.
  Future<Produto> aplicarPromocao(Produto produto, int percentual);

  Future<int> popularDemo();
}

/// Estratégia offline-first (C4.4):
/// * leituras vão ao Supabase e atualizam o cache local; sem conexão,
///   o cache local é usado e a UI é avisada (`doCache`);
/// * movimentações sem conexão entram na fila e são enviadas depois;
/// * cadastro/edição exigem conexão (precisam de validação do servidor).
class ProdutoRepositoryImpl implements ProdutoRepository {
  ProdutoRepositoryImpl({
    required SupabaseProdutoDataSource remote,
    required ProdutoLocalDataSource local,
    required PendenciasLocalDataSource pendencias,
  }) : _remote = remote,
       _local = local,
       _pendencias = pendencias;

  final SupabaseProdutoDataSource _remote;
  final ProdutoLocalDataSource _local;
  final PendenciasLocalDataSource _pendencias;

  @override
  Future<Pagina<Produto>> listar({
    required String empresaId,
    String busca = '',
    FiltroEstoque filtro = FiltroEstoque.todos,
    int pagina = 0,
    int tamanho = 20,
  }) async {
    final offset = pagina * tamanho;
    try {
      final itens = await _remote.listar(
        empresaId: empresaId,
        busca: busca,
        filtro: filtro,
        offset: offset,
        limite: tamanho,
      );
      await _local.salvarTodos(itens);
      return Pagina(itens: itens, temMais: itens.length == tamanho);
    } catch (e) {
      if (!ErrorMapper.isNetwork(e)) throw ErrorMapper.map(e);
      final itens = await _local.listar(
        empresaId: empresaId,
        busca: busca,
        offset: offset,
        limite: tamanho,
        somenteCriticos: filtro == FiltroEstoque.criticos,
        validadeAte: filtro == FiltroEstoque.vencendo
            ? DateTime.now().add(const Duration(days: 30))
            : null,
      );
      return Pagina(itens: itens, temMais: itens.length == tamanho, doCache: true);
    }
  }

  @override
  Future<Produto> buscarPorId(String id) async {
    try {
      final produto = await _remote.buscarPorId(id);
      await _local.salvar(produto);
      return produto;
    } catch (e) {
      if (!ErrorMapper.isNetwork(e)) throw ErrorMapper.map(e);
      final local = await _local.buscarPorId(id);
      if (local == null) throw const NetworkException();
      return local;
    }
  }

  @override
  Future<Produto?> buscarPorCodigo(String empresaId, String codigo) async {
    try {
      return await _remote.buscarPorCodigo(empresaId, codigo);
    } catch (e) {
      if (!ErrorMapper.isNetwork(e)) throw ErrorMapper.map(e);
      return _local.buscarPorCodigo(empresaId, codigo);
    }
  }

  @override
  Future<Produto> criar(Produto produto) async {
    try {
      final criado = await _remote.criar(produto);
      await _local.salvar(criado);
      return criado;
    } catch (e) {
      throw _exigeConexao(e);
    }
  }

  @override
  Future<Produto> atualizar(Produto produto) async {
    try {
      final atualizado = await _remote.atualizar(produto);
      await _local.salvar(atualizado);
      return atualizado;
    } catch (e) {
      throw _exigeConexao(e);
    }
  }

  @override
  Future<void> excluir(Produto produto) async {
    try {
      await _remote.definirAtivo(produto.id, ativo: false);
      await _local.remover(produto.id);
    } catch (e) {
      throw _exigeConexao(e);
    }
  }

  @override
  Future<void> restaurar(Produto produto) async {
    try {
      await _remote.definirAtivo(produto.id, ativo: true);
      await _local.salvar(produto.copyWith(ativo: true));
    } catch (e) {
      throw _exigeConexao(e);
    }
  }

  @override
  Future<ResultadoOperacao<Produto>> movimentar({
    required Produto produto,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  }) async {
    final operacaoId = IdGenerator.uuidV4();
    try {
      final atualizado = await _remote.movimentar(
        operacaoId: operacaoId,
        produtoId: produto.id,
        tipo: tipo,
        quantidade: quantidade,
        observacao: observacao,
      );
      await _local.salvar(atualizado);
      return ResultadoOperacao(atualizado);
    } catch (e) {
      if (!ErrorMapper.isNetwork(e)) throw ErrorMapper.map(e);

      // Sem conexão: valida localmente, enfileira e atualiza o cache.
      final novo = switch (tipo) {
        TipoMovimentacao.entrada => produto.quantidade + quantidade,
        TipoMovimentacao.saida || TipoMovimentacao.venda => produto.quantidade - quantidade,
        TipoMovimentacao.ajuste => quantidade,
      };
      if (novo < 0) {
        throw AppException('Estoque insuficiente: há apenas ${produto.quantidade} unidade(s).');
      }
      await _pendencias.adicionar(
        OperacaoPendente(
          tipo: TipoOperacao.movimentacao,
          criadaEm: DateTime.now(),
          payload: {
            'id': operacaoId,
            'produto_id': produto.id,
            'produto_nome': produto.nome,
            'tipo': tipo.name,
            'tipo_label': tipo.label,
            'quantidade': quantidade,
            'observacao': observacao,
          },
        ),
      );
      final otimista = produto.copyWith(quantidade: novo);
      await _local.salvar(otimista);
      return ResultadoOperacao(otimista, pendente: true);
    }
  }

  /// Usado pela sincronização da fila offline.
  Future<void> enviarMovimentacaoPendente(Map<String, dynamic> payload) async {
    try {
      final atualizado = await _remote.movimentar(
        operacaoId: payload['id'] as String,
        produtoId: payload['produto_id'] as String,
        tipo: TipoMovimentacao.fromName(payload['tipo'] as String?),
        quantidade: payload['quantidade'] as int,
        observacao: payload['observacao'] as String?,
      );
      await _local.salvar(atualizado);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  @override
  Future<Pagina<Movimentacao>> historico(String produtoId, {int pagina = 0, int tamanho = 20}) async {
    try {
      final itens = await _remote.historico(produtoId, offset: pagina * tamanho, limite: tamanho);
      return Pagina(itens: itens, temMais: itens.length == tamanho);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  @override
  Future<Produto> aplicarPromocao(Produto produto, int percentual) async {
    try {
      final atualizado = await _remote.aplicarPromocao(produto.id, percentual);
      await _local.salvar(atualizado);
      return atualizado;
    } catch (e) {
      throw _exigeConexao(e);
    }
  }

  @override
  Future<int> popularDemo() async {
    try {
      return await _remote.popularDemo();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  AppException _exigeConexao(Object e) {
    final mapped = ErrorMapper.map(e);
    if (mapped is NetworkException || mapped is TimeoutAppException) {
      return const NetworkException(
        'Sem conexão. Cadastro e edição de produtos precisam de internet.',
      );
    }
    return mapped;
  }
}
