import 'json_utils.dart';

enum TipoMovimentacao {
  entrada('Entrada'),
  saida('Saída'),
  ajuste('Ajuste de inventário'),
  venda('Venda');

  const TipoMovimentacao(this.label);

  final String label;

  static TipoMovimentacao fromName(String? value) => TipoMovimentacao.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TipoMovimentacao.ajuste,
  );
}

class Movimentacao {
  const Movimentacao({
    required this.id,
    required this.produtoId,
    required this.tipo,
    required this.quantidade,
    required this.saldoApos,
    required this.criadaEm,
    this.usuarioNome,
    this.observacao,
  });

  final String id;
  final String produtoId;
  final TipoMovimentacao tipo;
  final int quantidade;
  final int saldoApos;
  final DateTime criadaEm;
  final String? usuarioNome;
  final String? observacao;

  /// Sinal para exibição: entradas somam, saídas e vendas subtraem.
  String get quantidadeFormatada => switch (tipo) {
    TipoMovimentacao.entrada => '+$quantidade',
    TipoMovimentacao.saida || TipoMovimentacao.venda => '-$quantidade',
    TipoMovimentacao.ajuste => '= $saldoApos',
  };

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    final usuario = json['perfis'];
    return Movimentacao(
      id: json['id'] as String,
      produtoId: json['produto_id'] as String,
      tipo: TipoMovimentacao.fromName(json['tipo'] as String?),
      quantidade: JsonUtils.toInt(json['quantidade']),
      saldoApos: JsonUtils.toInt(json['saldo_apos']),
      criadaEm: JsonUtils.toDate(json['created_at']) ?? DateTime.now(),
      usuarioNome: usuario is Map<String, dynamic> ? usuario['nome'] as String? : null,
      observacao: json['observacao'] as String?,
    );
  }
}
