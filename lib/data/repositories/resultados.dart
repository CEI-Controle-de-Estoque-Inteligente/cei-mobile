/// Página de resultados de uma listagem paginada (C3.3).
class Pagina<T> {
  const Pagina({required this.itens, required this.temMais, this.doCache = false});

  final List<T> itens;
  final bool temMais;

  /// `true` quando veio do banco local por falta de conexão.
  final bool doCache;
}

/// Resultado de uma operação que pode ter ficado na fila offline.
class ResultadoOperacao<T> {
  const ResultadoOperacao(this.valor, {this.pendente = false});

  final T valor;

  /// `true` quando a operação foi salva localmente e será enviada depois.
  final bool pendente;
}
