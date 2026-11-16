import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/produto.dart';
import 'status_badge.dart';
import 'stock_level_bar.dart';
import 'validade_chip.dart';

/// Card de produto usado na listagem de estoque, alertas e nova venda.
class ProdutoCard extends StatelessWidget {
  const ProdutoCard({super.key, required this.produto, this.onTap, this.trailing});

  final Produto produto;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produto.nome,
                          style: textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (produto.categoria != null)
                          Text(
                            produto.categoria!,
                            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge.estoque(context, produto.status),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              StockLevelBar(produto: produto),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${produto.quantidade} un.', style: textTheme.bodyMedium),
                  Text(Formatters.currency(produto.preco), style: textTheme.bodyMedium),
                  ValidadeChip(produto: produto),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
