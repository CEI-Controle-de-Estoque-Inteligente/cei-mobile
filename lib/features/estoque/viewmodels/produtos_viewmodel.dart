import '../../../core/errors/app_exception.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/resultados.dart';
import '../../../shared/viewmodels/paginated_viewmodel.dart';

/// Listagem de estoque com busca (debounce), filtros e scroll infinito.
class ProdutosViewModel extends PaginatedViewModel<Produto> {
  ProdutosViewModel(this._repository, this.empresaId);

  final ProdutoRepository _repository;
  final String empresaId;
  final Debouncer _debouncer = Debouncer();

  String _busca = '';
  FiltroEstoque _filtro = FiltroEstoque.todos;

  String get busca => _busca;
  FiltroEstoque get filtro => _filtro;

  @override
  Future<Pagina<Produto>> buscarPagina(int pagina) =>
      _repository.listar(empresaId: empresaId, busca: _busca, filtro: _filtro, pagina: pagina);

  void buscar(String texto) {
    _busca = texto;
    _debouncer.run(recarregar);
  }

  void filtrar(FiltroEstoque filtro) {
    if (filtro == _filtro) return;
    _filtro = filtro;
    recarregar();
  }

  void produtoAtualizado(Produto produto) => substituirItem((p) => p.id == produto.id, produto);

  /// Exclusão com "Desfazer" (C4.6). Retorna o índice para restaurar.
  Future<int> excluir(Produto produto) async {
    final indice = itens.indexWhere((p) => p.id == produto.id);
    removerItem((p) => p.id == produto.id);
    try {
      await _repository.excluir(produto);
      return indice;
    } on AppException {
      inserirItem(indice, produto);
      rethrow;
    }
  }

  Future<void> desfazerExclusao(Produto produto, int indice) async {
    await _repository.restaurar(produto);
    inserirItem(indice, produto);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }
}
