import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../data/repositories/resultados.dart';

/// Base reutilizável para listas paginadas com estados Aguardando / Erro /
/// Vazio / Sucesso (C3.3 / C5.3). As subclasses só implementam [buscarPagina].
abstract class PaginatedViewModel<T> extends ChangeNotifier {
  final List<T> _itens = [];
  int _pagina = 0;
  bool _carregando = false;
  bool _carregandoMais = false;
  bool _temMais = true;
  bool _doCache = false;
  String? _erro;
  bool _disposed = false;
  int _requisicao = 0;

  List<T> get itens => List.unmodifiable(_itens);
  bool get carregando => _carregando;
  bool get carregandoMais => _carregandoMais;
  bool get temMais => _temMais;
  bool get doCache => _doCache;
  String? get erro => _erro;
  bool get vazio => !_carregando && _erro == null && _itens.isEmpty;

  @protected
  Future<Pagina<T>> buscarPagina(int pagina);

  /// Recarrega do zero (busca, filtro, pull-to-refresh).
  Future<void> recarregar() async {
    final req = ++_requisicao;
    _carregando = _itens.isEmpty;
    _erro = null;
    _notify();
    try {
      final pagina = await buscarPagina(0);
      if (req != _requisicao) return; // resposta antiga: descarta
      _itens
        ..clear()
        ..addAll(pagina.itens);
      _pagina = 0;
      _temMais = pagina.temMais;
      _doCache = pagina.doCache;
    } on AppException catch (e) {
      if (req != _requisicao) return;
      _erro = e.message;
      _itens.clear();
    } finally {
      if (req == _requisicao) {
        _carregando = false;
        _notify();
      }
    }
  }

  Future<void> carregarMais() async {
    if (_carregandoMais || !_temMais || _carregando) return;
    final req = _requisicao;
    _carregandoMais = true;
    _notify();
    try {
      final pagina = await buscarPagina(_pagina + 1);
      if (req != _requisicao) return;
      _itens.addAll(pagina.itens);
      _pagina++;
      _temMais = pagina.temMais;
    } on AppException {
      _temMais = false; // evita repetir falhas no scroll; pull-to-refresh tenta de novo
    } finally {
      _carregandoMais = false;
      _notify();
    }
  }

  @protected
  void substituirItem(bool Function(T item) onde, T novo) {
    final i = _itens.indexWhere(onde);
    if (i < 0) return;
    _itens[i] = novo;
    _notify();
  }

  @protected
  void removerItem(bool Function(T item) onde) {
    _itens.removeWhere(onde);
    _notify();
  }

  @protected
  void inserirItem(int indice, T item) {
    _itens.insert(indice.clamp(0, _itens.length), item);
    _notify();
  }

  @protected
  void notificar() => _notify();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
