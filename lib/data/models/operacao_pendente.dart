import 'dart:convert';

enum TipoOperacao { venda, movimentacao }

/// Operação registrada sem internet, aguardando sincronização (C4.4).
class OperacaoPendente {
  const OperacaoPendente({
    this.id,
    required this.tipo,
    required this.payload,
    required this.criadaEm,
    this.tentativas = 0,
    this.erro,
  });

  final int? id;
  final TipoOperacao tipo;
  final Map<String, dynamic> payload;
  final DateTime criadaEm;
  final int tentativas;

  /// Motivo da rejeição pelo servidor (ex.: estoque insuficiente).
  final String? erro;

  String get descricao {
    final produto = payload['produto_nome'] ?? 'produto';
    final qtd = payload['quantidade'];
    return switch (tipo) {
      TipoOperacao.venda => 'Venda de $qtd x $produto',
      TipoOperacao.movimentacao => '${payload['tipo_label'] ?? 'Movimentação'} de $qtd x $produto',
    };
  }

  factory OperacaoPendente.fromMap(Map<String, Object?> map) => OperacaoPendente(
    id: map['id'] as int?,
    tipo: TipoOperacao.values.byName(map['tipo']! as String),
    payload: jsonDecode(map['payload']! as String) as Map<String, dynamic>,
    criadaEm: DateTime.parse(map['criada_em']! as String),
    tentativas: (map['tentativas'] as int?) ?? 0,
    erro: map['erro'] as String?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'tipo': tipo.name,
    'payload': jsonEncode(payload),
    'criada_em': criadaEm.toIso8601String(),
    'tentativas': tentativas,
    'erro': erro,
  };
}
