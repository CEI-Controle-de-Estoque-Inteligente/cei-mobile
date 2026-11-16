import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/utils/id_generator.dart';
import '../local/pendencias_local_datasource.dart';
import '../local/produto_local_datasource.dart';
import '../models/operacao_pendente.dart';
import '../models/produto.dart';
import '../models/venda.dart';
import '../remote/supabase_venda_datasource.dart';
import 'resultados.dart';

abstract interface class VendaRepository {
  Future<ResultadoOperacao<Venda>> registrar({
    required Produto produto,
    required int quantidade,
    required String operadorId,
  });

  Future<Pagina<Venda>> listar({
    required IntervaloDatas intervalo,
    String? operadorId,
    int pagina = 0,
    int tamanho = 20,
  });

  Future<ResumoVendas> resumo({required IntervaloDatas intervalo, String? operadorId});
}

class VendaRepositoryImpl implements VendaRepository {
  VendaRepositoryImpl({
    required SupabaseVendaDataSource remote,
    required ProdutoLocalDataSource produtosLocal,
    required PendenciasLocalDataSource pendencias,
  }) : _remote = remote,
       _produtosLocal = produtosLocal,
       _pendencias = pendencias;

  final SupabaseVendaDataSource _remote;
  final ProdutoLocalDataSource _produtosLocal;
  final PendenciasLocalDataSource _pendencias;

  @override
  Future<ResultadoOperacao<Venda>> registrar({
    required Produto produto,
    required int quantidade,
    required String operadorId,
  }) async {
    if (quantidade > produto.quantidade) {
      throw AppException('Estoque insuficiente: há apenas ${produto.quantidade} unidade(s).');
    }
    final vendaId = IdGenerator.uuidV4();
    try {
      final venda = await _remote.registrar(
        vendaId: vendaId,
        produtoId: produto.id,
        quantidade: quantidade,
      );
      await _produtosLocal.salvar(produto.copyWith(quantidade: produto.quantidade - quantidade));
      return ResultadoOperacao(venda);
    } catch (e) {
      if (!ErrorMapper.isNetwork(e)) throw ErrorMapper.map(e);

      // Sem conexão: registra na fila e baixa o estoque local.
      await _pendencias.adicionar(
        OperacaoPendente(
          tipo: TipoOperacao.venda,
          criadaEm: DateTime.now(),
          payload: {
            'id': vendaId,
            'produto_id': produto.id,
            'produto_nome': produto.nome,
            'quantidade': quantidade,
          },
        ),
      );
      await _produtosLocal.salvar(produto.copyWith(quantidade: produto.quantidade - quantidade));
      final venda = Venda(
        id: vendaId,
        produtoId: produto.id,
        produtoNome: produto.nome,
        quantidade: quantidade,
        precoUnitario: produto.preco,
        total: produto.preco * quantidade,
        criadaEm: DateTime.now(),
        operadorId: operadorId,
        pendente: true,
      );
      return ResultadoOperacao(venda, pendente: true);
    }
  }

  /// Usado pela sincronização da fila offline.
  Future<void> enviarVendaPendente(Map<String, dynamic> payload) async {
    try {
      await _remote.registrar(
        vendaId: payload['id'] as String,
        produtoId: payload['produto_id'] as String,
        quantidade: payload['quantidade'] as int,
      );
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  @override
  Future<Pagina<Venda>> listar({
    required IntervaloDatas intervalo,
    String? operadorId,
    int pagina = 0,
    int tamanho = 20,
  }) async {
    try {
      final itens = await _remote.listar(
        intervalo: intervalo,
        operadorId: operadorId,
        offset: pagina * tamanho,
        limite: tamanho,
      );
      return Pagina(itens: itens, temMais: itens.length == tamanho);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  @override
  Future<ResumoVendas> resumo({required IntervaloDatas intervalo, String? operadorId}) async {
    try {
      return await _remote.resumo(intervalo: intervalo, operadorId: operadorId);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
