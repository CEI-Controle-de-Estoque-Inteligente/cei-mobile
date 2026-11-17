import 'json_utils.dart';
import 'tabela_descontos.dart';

/// Situação do nível de estoque (badges OK / Atenção / Baixo / Crítico).
enum StockStatus {
  ok('OK'),
  atencao('Atenção'),
  baixo('Baixo'),
  critico('Crítico');

  const StockStatus(this.label);

  final String label;

  /// Mesma regra da coluna gerada `status` no banco.
  static StockStatus calcular({required int quantidade, required int minimo}) {
    if (quantidade == 0 || quantidade <= minimo ~/ 2) return StockStatus.critico;
    if (quantidade <= minimo) return StockStatus.baixo;
    if (quantidade <= minimo * 1.5) return StockStatus.atencao;
    return StockStatus.ok;
  }
}

/// Faixas de alerta de validade (RN: 30, 15 e 5 dias antes do vencimento).
enum AlertaValidade {
  vencido('Vencido'),
  critico('Vence em até 5 dias'),
  alto('Vence em até 15 dias'),
  medio('Vence em até 30 dias');

  const AlertaValidade(this.label);

  final String label;
}

class Produto {
  const Produto({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.preco,
    required this.quantidade,
    required this.estoqueMinimo,
    required this.estoqueMaximo,
    this.categoria,
    this.codigoBarras,
    this.validade,
    this.ativo = true,
    this.updatedAt,
    this.promocaoPercentual,
    this.precoPromocional,
  });

  final String id;
  final String empresaId;
  final String nome;
  final String? categoria;
  final String? codigoBarras;
  final double preco;
  final int quantidade;
  final int estoqueMinimo;
  final int estoqueMaximo;
  final DateTime? validade;
  final bool ativo;
  final DateTime? updatedAt;

  /// Promoção aplicada pelo gerente (null = sem promoção).
  final int? promocaoPercentual;
  final double? precoPromocional;

  bool get emPromocao => promocaoPercentual != null && precoPromocional != null;

  /// Preço cobrado na venda (promocional quando houver).
  double get precoVenda => emPromocao ? precoPromocional! : preco;

  StockStatus get status =>
      StockStatus.calcular(quantidade: quantidade, minimo: estoqueMinimo);

  /// Nível de 0 a 1 para a barra visual (atual vs capacidade máxima).
  double get nivel {
    final capacidade = estoqueMaximo > 0
        ? estoqueMaximo
        : (estoqueMinimo > 0 ? estoqueMinimo * 2 : quantidade);
    if (capacidade <= 0) return 0;
    return (quantidade / capacidade).clamp(0, 1).toDouble();
  }

  /// Dias até o vencimento (negativo = vencido). `null` = sem validade.
  int? diasParaVencer([DateTime? hoje]) {
    if (validade == null) return null;
    final base = hoje ?? DateTime.now();
    final h = DateTime(base.year, base.month, base.day);
    final v = DateTime(validade!.year, validade!.month, validade!.day);
    return v.difference(h).inDays;
  }

  AlertaValidade? alertaValidade([DateTime? hoje]) {
    final dias = diasParaVencer(hoje);
    if (dias == null) return null;
    if (dias < 0) return AlertaValidade.vencido;
    if (dias <= 5) return AlertaValidade.critico;
    if (dias <= 15) return AlertaValidade.alto;
    if (dias <= 30) return AlertaValidade.medio;
    return null;
  }

  /// RN002 (Estoque): sugestão automática de desconto para itens com
  /// menos de 7 dias para vencer, conforme a tabela definida pelo gerente.
  /// Não sugere quando já há promoção ativa ou não há estoque.
  int? descontoSugerido({TabelaDescontos tabela = TabelaDescontos.padrao, DateTime? hoje}) {
    final dias = diasParaVencer(hoje);
    if (dias == null || quantidade == 0 || emPromocao) return null;
    return tabela.percentualPara(dias);
  }

  /// Preço com [percentual] de desconto, arredondado como no banco.
  double precoComDesconto(int percentual) =>
      (preco * (100 - percentual) / 100 * 100).roundToDouble() / 100;

  double get valorEmEstoque => preco * quantidade;

  // ---------------------------------------------------------------- remoto

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      nome: json['nome'] as String,
      categoria: json['categoria'] as String?,
      codigoBarras: json['codigo_barras'] as String?,
      preco: JsonUtils.toDouble(json['preco']),
      quantidade: JsonUtils.toInt(json['quantidade']),
      estoqueMinimo: JsonUtils.toInt(json['estoque_minimo']),
      estoqueMaximo: JsonUtils.toInt(json['estoque_maximo']),
      validade: JsonUtils.toDate(json['validade']),
      ativo: (json['ativo'] as bool?) ?? true,
      updatedAt: JsonUtils.toDate(json['updated_at']),
      promocaoPercentual: json['promocao_percentual'] == null ? null : JsonUtils.toInt(json['promocao_percentual']),
      precoPromocional: json['preco_promocional'] == null ? null : JsonUtils.toDouble(json['preco_promocional']),
    );
  }

  /// Campos enviados ao criar/editar (quantidade só no cadastro inicial).
  Map<String, dynamic> toJson({bool incluirQuantidade = false}) => {
    'empresa_id': empresaId,
    'nome': nome.trim(),
    'categoria': JsonUtils.emptyToNull(categoria),
    'codigo_barras': JsonUtils.emptyToNull(codigoBarras),
    'preco': preco,
    'estoque_minimo': estoqueMinimo,
    'estoque_maximo': estoqueMaximo,
    'validade': validade == null ? null : JsonUtils.dateOnly(validade!),
    if (incluirQuantidade) 'quantidade': quantidade,
  };

  // ----------------------------------------------------------------- local

  factory Produto.fromMap(Map<String, Object?> map) {
    return Produto(
      id: map['id']! as String,
      empresaId: map['empresa_id']! as String,
      nome: map['nome']! as String,
      categoria: map['categoria'] as String?,
      codigoBarras: map['codigo_barras'] as String?,
      preco: JsonUtils.toDouble(map['preco']),
      quantidade: JsonUtils.toInt(map['quantidade']),
      estoqueMinimo: JsonUtils.toInt(map['estoque_minimo']),
      estoqueMaximo: JsonUtils.toInt(map['estoque_maximo']),
      validade: JsonUtils.toDate(map['validade']),
      ativo: map['ativo'] == 1,
      updatedAt: JsonUtils.toDate(map['updated_at']),
      promocaoPercentual: map['promocao_percentual'] == null ? null : JsonUtils.toInt(map['promocao_percentual']),
      precoPromocional: map['preco_promocional'] == null ? null : JsonUtils.toDouble(map['preco_promocional']),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'empresa_id': empresaId,
    'nome': nome,
    'nome_busca': nome.toLowerCase(),
    'categoria': categoria,
    'codigo_barras': codigoBarras,
    'preco': preco,
    'quantidade': quantidade,
    'estoque_minimo': estoqueMinimo,
    'estoque_maximo': estoqueMaximo,
    'validade': validade == null ? null : JsonUtils.dateOnly(validade!),
    'ativo': ativo ? 1 : 0,
    'updated_at': updatedAt?.toIso8601String(),
    'promocao_percentual': promocaoPercentual,
    'preco_promocional': precoPromocional,
  };

  Produto copyWith({
    String? id,
    String? nome,
    String? categoria,
    String? codigoBarras,
    double? preco,
    int? quantidade,
    int? estoqueMinimo,
    int? estoqueMaximo,
    DateTime? validade,
    bool limparValidade = false,
    bool? ativo,
  }) {
    return Produto(
      id: id ?? this.id,
      empresaId: empresaId,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      preco: preco ?? this.preco,
      quantidade: quantidade ?? this.quantidade,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      estoqueMaximo: estoqueMaximo ?? this.estoqueMaximo,
      validade: limparValidade ? null : (validade ?? this.validade),
      ativo: ativo ?? this.ativo,
      updatedAt: updatedAt,
      promocaoPercentual: promocaoPercentual,
      precoPromocional: precoPromocional,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Produto &&
      other.id == id &&
      other.updatedAt == updatedAt &&
      other.quantidade == quantidade &&
      other.promocaoPercentual == promocaoPercentual;

  @override
  int get hashCode => Object.hash(id, updatedAt, quantidade, promocaoPercentual);
}
