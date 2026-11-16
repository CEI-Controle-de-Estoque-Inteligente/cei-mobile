import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/models/perfil.dart';
import '../../data/models/produto.dart';

/// Etiqueta colorida de status (OK / Atenção / Baixo / Crítico, Ativo...).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  factory StatusBadge.estoque(BuildContext context, StockStatus status) {
    return StatusBadge(label: status.label, color: corEstoque(context, status));
  }

  factory StatusBadge.funcionario(BuildContext context, StatusFuncionario status) {
    final cores = Theme.of(context).extension<StockStatusColors>()!;
    final color = switch (status) {
      StatusFuncionario.ativo => cores.ok,
      StatusFuncionario.ferias => cores.low,
      StatusFuncionario.afastado => cores.critical,
    };
    return StatusBadge(label: status.label, color: color);
  }

  static Color corEstoque(BuildContext context, StockStatus status) {
    final cores = Theme.of(context).extension<StockStatusColors>()!;
    return switch (status) {
      StockStatus.ok => cores.ok,
      StockStatus.atencao => cores.low,
      StockStatus.baixo => cores.low,
      StockStatus.critico => cores.critical,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.25 : 0.14),
          borderRadius: AppRadius.smAll,
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
