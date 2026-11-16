import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/movimentacao.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/resultados.dart';

class MovimentacaoViewModel extends ChangeNotifier {
  MovimentacaoViewModel(this._repository, this.produto);

  final ProdutoRepository _repository;
  final Produto produto;

  TipoMovimentacao _tipo = TipoMovimentacao.entrada;
  int _quantidade = 0;
  bool _salvando = false;
  String? _erro;
  bool _disposed = false;

  TipoMovimentacao get tipo => _tipo;
  bool get salvando => _salvando;
  String? get erro => _erro;

  /// Prévia do saldo após a operação (regra de negócio no ViewModel).
  int get saldoPrevisto => switch (_tipo) {
    TipoMovimentacao.entrada => produto.quantidade + _quantidade,
    TipoMovimentacao.saida || TipoMovimentacao.venda => produto.quantidade - _quantidade,
    TipoMovimentacao.ajuste => _quantidade,
  };

  String? validarQuantidade(String? texto) {
    final valor = int.tryParse(texto?.trim() ?? '');
    if (valor == null) return 'Informe a quantidade';
    if (_tipo != TipoMovimentacao.ajuste && valor <= 0) return 'A quantidade deve ser maior que zero';
    if (_tipo == TipoMovimentacao.ajuste && valor < 0) return 'O saldo não pode ser negativo';
    if (_tipo == TipoMovimentacao.saida && valor > produto.quantidade) {
      return 'Há apenas ${produto.quantidade} unidade(s) em estoque';
    }
    return null;
  }

  void alterarTipo(TipoMovimentacao tipo) {
    _tipo = tipo;
    _notify();
  }

  void alterarQuantidade(String texto) {
    _quantidade = int.tryParse(texto.trim()) ?? 0;
    _notify();
  }

  Future<ResultadoOperacao<Produto>?> salvar(String? observacao) async {
    _salvando = true;
    _erro = null;
    _notify();
    try {
      return await _repository.movimentar(
        produto: produto,
        tipo: _tipo,
        quantidade: _quantidade,
        observacao: observacao,
      );
    } on AppException catch (e) {
      _erro = e.message;
      return null;
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
