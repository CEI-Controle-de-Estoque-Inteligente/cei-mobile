import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Marca do CEI (ícone + nome). Componente reutilizável (C1.3).
class CeiLogo extends StatelessWidget {
  const CeiLogo({super.key, this.size = 72, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Logotipo CEI - Controle de Estoque Inteligente',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: AppRadius.lgAll,
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              size: size * 0.55,
              color: colors.onPrimary,
            ),
          ),
          if (showName) ...[
            const SizedBox(height: AppSpacing.md),
            Text('CEI', style: textTheme.headlineMedium),
            Text(
              'Controle de Estoque Inteligente',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
