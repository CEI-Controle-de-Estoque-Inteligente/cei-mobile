import 'json_utils.dart';

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
  /// menos de 7 dias para vencer. Quanto mais perto, maior o desconto.
  int? descontoSugerido([DateTime? hoje]) {
    final dias = diasParaVencer(hoje);
    if (dias == null || dias < 0 || dias >= 7 || quantidade == 0) return null;
    if (dias <= 1) return 50;
    if (dias <= 3) return 30;
    if (dias <= 5) return 20;
    return 10;
  }

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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Produto && other.id == id && other.updatedAt == updatedAt && other.quantidade == quantidade;

  @override
  int get hashCode => Object.hash(id, updatedAt, quantidade);
}
