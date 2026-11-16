import 'json_utils.dart';

class Venda {
  const Venda({
    required this.id,
    required this.produtoNome,
    required this.quantidade,
    required this.precoUnitario,
    required this.total,
    required this.criadaEm,
    this.produtoId,
    this.operadorId,
    this.operadorNome,
    this.pendente = false,
  });

  final String id;
  final String? produtoId;
  final String produtoNome;
  final int quantidade;
  final double precoUnitario;
  final double total;
  final DateTime criadaEm;
  final String? operadorId;
  final String? operadorNome;

  /// Registrada offline e ainda não enviada ao servidor.
  final bool pendente;

  factory Venda.fromJson(Map<String, dynamic> json) {
    final operador = json['perfis'];
    return Venda(
      id: json['id'] as String,
      produtoId: json['produto_id'] as String?,
      produtoNome: (json['produto_nome'] as String?) ?? 'Produto removido',
      quantidade: JsonUtils.toInt(json['quantidade']),
      precoUnitario: JsonUtils.toDouble(json['preco_unitario']),
      total: JsonUtils.toDouble(json['total']),
      criadaEm: JsonUtils.toDate(json['created_at']) ?? DateTime.now(),
      operadorId: json['operador_id'] as String?,
      operadorNome: operador is Map<String, dynamic> ? operador['nome'] as String? : null,
    );
  }
}

/// Totais do período (RN002 - ticket médio = total / nº de transações).
class ResumoVendas {
  const ResumoVendas({required this.total, required this.transacoes, required this.ticketMedio});

  final double total;
  final int transacoes;
  final double ticketMedio;

  static const ResumoVendas vazio = ResumoVendas(total: 0, transacoes: 0, ticketMedio: 0);

  factory ResumoVendas.fromJson(Map<String, dynamic> json) => ResumoVendas(
    total: JsonUtils.toDouble(json['total']),
    transacoes: JsonUtils.toInt(json['transacoes']),
    ticketMedio: JsonUtils.toDouble(json['ticket_medio']),
  );

  /// Cálculo local (usado em testes e no modo offline).
  factory ResumoVendas.calcular(Iterable<Venda> vendas) {
    final lista = vendas.toList();
    final total = lista.fold<double>(0, (soma, v) => soma + v.total);
    return ResumoVendas(
      total: total,
      transacoes: lista.length,
      ticketMedio: lista.isEmpty ? 0 : total / lista.length,
    );
  }
}

/// Filtros de período da tela Minhas Vendas.
enum PeriodoVendas {
  hoje('Hoje'),
  semana('7 dias'),
  mes('30 dias'),
  personalizado('Personalizado');

  const PeriodoVendas(this.label);

  final String label;
}

class IntervaloDatas {
  const IntervaloDatas(this.inicio, this.fim);

  final DateTime inicio;

  /// Exclusivo.
  final DateTime fim;

  factory IntervaloDatas.de(PeriodoVendas periodo, {DateTime? agora}) {
    final now = agora ?? DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);
    final amanha = hoje.add(const Duration(days: 1));
    return switch (periodo) {
      PeriodoVendas.hoje => IntervaloDatas(hoje, amanha),
      PeriodoVendas.semana => IntervaloDatas(hoje.subtract(const Duration(days: 6)), amanha),
      PeriodoVendas.mes || PeriodoVendas.personalizado =>
        IntervaloDatas(hoje.subtract(const Duration(days: 29)), amanha),
    };
  }
}
