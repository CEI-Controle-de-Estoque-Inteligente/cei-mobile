import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/models/venda.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/resultados.dart';
import '../../../data/repositories/venda_repository.dart';

class NovaVendaViewModel extends ChangeNotifier {
  NovaVendaViewModel({
    required ProdutoRepository produtos,
    required VendaRepository vendas,
    required this.perfil,
    Produto? produtoInicial,
  }) : _produtos = produtos,
       _vendas = vendas,
       _selecionado = produtoInicial;

  final ProdutoRepository _produtos;
  final VendaRepository _vendas;
  final Perfil perfil;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 350));

  Produto? _selecionado;
  int _quantidade = 1;
  List<Produto> _resultados = const [];
  bool _buscando = false;
  bool _salvando = false;
  String? _erro;
  String _busca = '';
  bool _disposed = false;

  Produto? get selecionado => _selecionado;
  int get quantidade => _quantidade;
  List<Produto> get resultados => _resultados;
  bool get buscando => _buscando;
  bool get salvando => _salvando;
  String? get erro => _erro;
  String get busca => _busca;
  /// Usa o preço promocional quando o produto está em promoção.
  double get total => (_selecionado?.precoVenda ?? 0) * _quantidade;
  bool get podeConfirmar =>
      _selecionado != null && _quantidade > 0 && _quantidade <= _selecionado!.quantidade && !_salvando;

  void buscar(String texto) {
    _busca = texto;
    _debouncer.run(_executarBusca);
  }

  Future<void> _executarBusca() async {
    final termo = _busca;
    _buscando = true;
    _erro = null;
    _notify();
    try {
      final pagina = await _produtos.listar(empresaId: perfil.empresaId, busca: termo);
      if (termo != _busca) return;
      _resultados = pagina.itens.where((p) => p.quantidade > 0).toList();
    } on AppException catch (e) {
      _erro = e.message;
    } finally {
      _buscando = false;
      _notify();
    }
  }

  Future<void> carregarIniciais() => _executarBusca();

  Future<bool> selecionarPorCodigo(String codigo) async {
    try {
      final produto = await _produtos.buscarPorCodigo(perfil.empresaId, codigo);
      if (produto == null) {
        _erro = 'Nenhum produto com o código $codigo.';
        _notify();
        return false;
      }
      selecionar(produto);
      return true;
    } on AppException catch (e) {
      _erro = e.message;
      _notify();
      return false;
    }
  }

  void selecionar(Produto produto) {
    _selecionado = produto;
    _quantidade = 1;
    _erro = produto.quantidade == 0 ? 'Produto sem estoque.' : null;
    _notify();
  }

  void limparSelecao() {
    _selecionado = null;
    _notify();
  }

  void alterarQuantidade(int delta) {
    final max = _selecionado?.quantidade ?? 1;
    _quantidade = (_quantidade + delta).clamp(1, max < 1 ? 1 : max);
    _notify();
  }

  Future<ResultadoOperacao<Venda>?> confirmar() async {
    final produto = _selecionado;
    if (produto == null) return null;
    _salvando = true;
    _erro = null;
    _notify();
    try {
      return await _vendas.registrar(produto: produto, quantidade: _quantidade, operadorId: perfil.id);
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
    _debouncer.dispose();
    super.dispose();
  }
}
