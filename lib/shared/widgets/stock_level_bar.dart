import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/models/produto.dart';
import 'status_badge.dart';

/// Barra visual do nível de estoque (verde / amarelo / vermelho).
class StockLevelBar extends StatelessWidget {
  const StockLevelBar({super.key, required this.produto, this.height = 8});

  final Produto produto;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = StatusBadge.corEstoque(context, produto.status);
    return Semantics(
      label: 'Nível de estoque ${(produto.nivel * 100).round()} por cento',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: AppRadius.smAll,
        child: LinearProgressIndicator(
          value: produto.nivel,
          minHeight: height,
          color: color,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
