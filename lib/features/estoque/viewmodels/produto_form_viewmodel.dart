import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/produto.dart';
import '../../../data/models/produto_externo.dart';
import '../../../data/remote/open_food_facts_service.dart';
import '../../../data/repositories/produto_repository.dart';

class ProdutoFormViewModel extends ChangeNotifier {
  ProdutoFormViewModel({
    required ProdutoRepository repository,
    required OpenFoodFactsService openFoodFacts,
    required this.empresaId,
    this.inicial,
  }) : _repository = repository,
       _openFoodFacts = openFoodFacts,
       _validade = inicial?.validade;

  final ProdutoRepository _repository;
  final OpenFoodFactsService _openFoodFacts;
  final String empresaId;
  final Produto? inicial;

  bool _salvando = false;
  bool _buscandoCodigo = false;
  String? _erro;
  DateTime? _validade;
  bool _disposed = false;

  bool get editando => inicial != null;
  bool get salvando => _salvando;
  bool get buscandoCodigo => _buscandoCodigo;
  String? get erro => _erro;
  DateTime? get validade => _validade;

  void definirValidade(DateTime? data) {
    _validade = data;
    _notify();
  }

  /// Consulta a API Open Food Facts para sugerir nome/categoria.
  Future<ProdutoExterno?> buscarPorCodigo(String codigo) async {
    _buscandoCodigo = true;
    _erro = null;
    _notify();
    try {
      final existente = await _repository.buscarPorCodigo(empresaId, codigo);
      if (existente != null && existente.id != inicial?.id) {
        _erro = 'Este código já está cadastrado em "${existente.nome}".';
        return null;
      }
      final externo = await _openFoodFacts.buscarPorCodigo(codigo);
      if (externo == null) _erro = 'Produto não encontrado na base pública. Preencha manualmente.';
      return externo;
    } on AppException catch (e) {
      _erro = e.message;
      return null;
    } finally {
      _buscandoCodigo = false;
      _notify();
    }
  }

  Future<Produto?> salvar({
    required String nome,
    required String? categoria,
    required String? codigoBarras,
    required double preco,
    required int quantidadeInicial,
    required int estoqueMinimo,
    required int estoqueMaximo,
  }) async {
    if (estoqueMaximo > 0 && estoqueMaximo < estoqueMinimo) {
      _erro = 'A capacidade máxima deve ser maior que o estoque mínimo.';
      _notify();
      return null;
    }
    _salvando = true;
    _erro = null;
    _notify();

    final base = inicial;
    final produto = Produto(
      id: base?.id ?? '',
      empresaId: empresaId,
      nome: nome,
      categoria: categoria,
      codigoBarras: codigoBarras,
      preco: preco,
      quantidade: base?.quantidade ?? quantidadeInicial,
      estoqueMinimo: estoqueMinimo,
      estoqueMaximo: estoqueMaximo,
      validade: _validade,
    );

    try {
      return base == null ? await _repository.criar(produto) : await _repository.atualizar(produto);
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
