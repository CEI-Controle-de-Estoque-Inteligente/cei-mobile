import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/movimentacao.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/resultados.dart';
import '../../../shared/viewmodels/paginated_viewmodel.dart';

class ProdutoDetalheViewModel extends ChangeNotifier {
  ProdutoDetalheViewModel(this._repository, this.produtoId, {Produto? inicial}) : _produto = inicial;

  final ProdutoRepository _repository;
  final String produtoId;

  Produto? _produto;
  bool _carregando = false;
  bool _excluindo = false;
  bool _salvandoPromocao = false;
  String? _erro;
  bool _disposed = false;

  Produto? get produto => _produto;
  bool get carregando => _carregando;
  bool get excluindo => _excluindo;
  bool get salvandoPromocao => _salvandoPromocao;
  String? get erro => _erro;

  Future<void> carregar() async {
    _carregando = _produto == null;
    _erro = null;
    _notify();
    try {
      _produto = await _repository.buscarPorId(produtoId);
    } on AppException catch (e) {
      if (_produto == null) _erro = e.message;
    } finally {
      _carregando = false;
      _notify();
    }
  }

  void atualizar(Produto produto) {
    _produto = produto;
    _notify();
  }

  /// Aplica (1 a 90%) ou encerra (0) a promoção.
  Future<void> aplicarPromocao(int percentual) async {
    final atual = _produto;
    if (atual == null) return;
    _salvandoPromocao = true;
    _notify();
    try {
      _produto = await _repository.aplicarPromocao(atual, percentual);
    } finally {
      _salvandoPromocao = false;
      _notify();
    }
  }

  Future<void> excluir() async {
    final atual = _produto;
    if (atual == null) return;
    _excluindo = true;
    _notify();
    try {
      await _repository.excluir(atual);
    } finally {
      _excluindo = false;
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

/// Histórico de movimentações do produto (paginado).
class HistoricoViewModel extends PaginatedViewModel<Movimentacao> {
  HistoricoViewModel(this._repository, this.produtoId);

  final ProdutoRepository _repository;
  final String produtoId;

  @override
  Future<Pagina<Movimentacao>> buscarPagina(int pagina) =>
      _repository.historico(produtoId, pagina: pagina);
}
