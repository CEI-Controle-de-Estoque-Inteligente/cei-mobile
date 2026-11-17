import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/produto.dart';
import '../descontos_context.dart';
import 'status_badge.dart';

/// Alerta de validade com dias restantes e sugestão de desconto (< 7 dias).
class ValidadeChip extends StatelessWidget {
  const ValidadeChip({super.key, required this.produto, this.mostrarDesconto = true});

  final Produto produto;
  final bool mostrarDesconto;

  @override
  Widget build(BuildContext context) {
    final dias = produto.diasParaVencer();
    final alerta = produto.alertaValidade();
    if (dias == null || alerta == null) return const SizedBox.shrink();

    final cores = Theme.of(context).extension<StockStatusColors>()!;
    final color = switch (alerta) {
      AlertaValidade.vencido || AlertaValidade.critico => cores.critical,
      AlertaValidade.alto => cores.low,
      AlertaValidade.medio => Theme.of(context).colorScheme.primary,
    };
    final texto = dias < 0
        ? 'Vencido há ${-dias}d'
        : (dias == 0 ? 'Vence hoje' : 'Vence em ${dias}d');
    final desconto = mostrarDesconto ? produto.descontoSugerido(tabela: tabelaDescontosDe(context)) : null;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        StatusBadge(label: texto, color: color, icon: Icons.event_busy_outlined),
        if (desconto != null)
          StatusBadge(label: 'Sugestão: $desconto% off', color: cores.low, icon: Icons.sell_outlined),
      ],
    );
  }
}
