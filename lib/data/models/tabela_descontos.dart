import 'json_utils.dart';

/// Percentuais de desconto sugeridos por faixa de dias até o vencimento.
/// Definidos pelo gerente em Configurações (0 = não sugerir na faixa).
class TabelaDescontos {
  const TabelaDescontos({
    required this.ate1Dia,
    required this.ate3Dias,
    required this.ate5Dias,
    required this.ate6Dias,
  });

  /// Vence hoje ou amanhã.
  final int ate1Dia;

  /// Vence em 2 ou 3 dias.
  final int ate3Dias;

  /// Vence em 4 ou 5 dias.
  final int ate5Dias;

  /// Vence em 6 dias.
  final int ate6Dias;

  static const TabelaDescontos padrao = TabelaDescontos(
    ate1Dia: 50,
    ate3Dias: 30,
    ate5Dias: 20,
    ate6Dias: 10,
  );

  static const int maximo = 90;

  /// Percentual para quem vence em [dias]; `null` fora da faixa (7+ dias ou
  /// vencido) ou quando o gerente zerou a faixa.
  int? percentualPara(int dias) {
    if (dias < 0 || dias >= 7) return null;
    final p = dias <= 1
        ? ate1Dia
        : dias <= 3
        ? ate3Dias
        : dias <= 5
        ? ate5Dias
        : ate6Dias;
    return p > 0 ? p : null;
  }

  factory TabelaDescontos.fromJson(Map<String, dynamic> json) {
    int ler(String chave, int padrao) =>
        json.containsKey(chave) && json[chave] != null ? JsonUtils.toInt(json[chave]) : padrao;
    return TabelaDescontos(
      ate1Dia: ler('desconto_1d', padrao.ate1Dia),
      ate3Dias: ler('desconto_3d', padrao.ate3Dias),
      ate5Dias: ler('desconto_5d', padrao.ate5Dias),
      ate6Dias: ler('desconto_6d', padrao.ate6Dias),
    );
  }

  Map<String, dynamic> toJson() => {
    'desconto_1d': ate1Dia,
    'desconto_3d': ate3Dias,
    'desconto_5d': ate5Dias,
    'desconto_6d': ate6Dias,
  };

  @override
  bool operator ==(Object other) =>
      other is TabelaDescontos &&
      other.ate1Dia == ate1Dia &&
      other.ate3Dias == ate3Dias &&
      other.ate5Dias == ate5Dias &&
      other.ate6Dias == ate6Dias;

  @override
  int get hashCode => Object.hash(ate1Dia, ate3Dias, ate5Dias, ate6Dias);
}
