import 'json_utils.dart';

class DashboardResumo {
  const DashboardResumo({
    required this.faturamentoHoje,
    required this.faturamentoOntem,
    required this.vendasHoje,
    required this.produtosAtivos,
    required this.itensEstoque,
    required this.itensCriticos,
    required this.vencendo15,
    required this.vencidos,
  });

  final double faturamentoHoje;
  final double faturamentoOntem;
  final int vendasHoje;
  final int produtosAtivos;
  final int itensEstoque;
  final int itensCriticos;
  final int vencendo15;
  final int vencidos;

  /// RN001 (Dashboard): variação percentual em relação ao dia anterior.
  /// `null` quando não houve faturamento ontem (não há base de comparação).
  double? get variacaoFaturamento {
    if (faturamentoOntem == 0) return null;
    return (faturamentoHoje - faturamentoOntem) / faturamentoOntem * 100;
  }

  factory DashboardResumo.fromJson(Map<String, dynamic> json) => DashboardResumo(
    faturamentoHoje: JsonUtils.toDouble(json['faturamento_hoje']),
    faturamentoOntem: JsonUtils.toDouble(json['faturamento_ontem']),
    vendasHoje: JsonUtils.toInt(json['vendas_hoje']),
    produtosAtivos: JsonUtils.toInt(json['produtos_ativos']),
    itensEstoque: JsonUtils.toInt(json['itens_estoque']),
    itensCriticos: JsonUtils.toInt(json['itens_criticos']),
    vencendo15: JsonUtils.toInt(json['vencendo_15']),
    vencidos: JsonUtils.toInt(json['vencidos']),
  );
}

/// Giro de um produto nos últimos dias (base da recomendação de compra).
class GiroProduto {
  const GiroProduto({
    required this.produtoId,
    required this.nome,
    required this.quantidade,
    required this.estoqueMinimo,
    required this.vendido,
    required this.mediaDiaria,
    this.diasCobertura,
  });

  final String produtoId;
  final String nome;
  final int quantidade;
  final int estoqueMinimo;
  final int vendido;
  final double mediaDiaria;

  /// Quantos dias o estoque atual dura no ritmo de vendas atual.
  final double? diasCobertura;

  /// Sugestão de compra para cobrir 30 dias de vendas + o estoque mínimo.
  int get sugestaoCompra {
    final alvo = (mediaDiaria * 30).ceil() + estoqueMinimo;
    final falta = alvo - quantidade;
    return falta > 0 ? falta : 0;
  }

  factory GiroProduto.fromJson(Map<String, dynamic> json) => GiroProduto(
    produtoId: json['produto_id'] as String,
    nome: json['nome'] as String,
    quantidade: JsonUtils.toInt(json['quantidade']),
    estoqueMinimo: JsonUtils.toInt(json['estoque_minimo']),
    vendido: JsonUtils.toInt(json['vendido']),
    mediaDiaria: JsonUtils.toDouble(json['media_diaria']),
    diasCobertura: json['dias_cobertura'] == null ? null : JsonUtils.toDouble(json['dias_cobertura']),
  );
}
