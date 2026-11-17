import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/produto.dart';
import 'status_badge.dart';

/// Preço do produto. Em promoção: preço promocional, preço cheio riscado
/// e etiqueta com o percentual.
class PrecoProduto extends StatelessWidget {
  const PrecoProduto({super.key, required this.produto, this.style});

  final Produto produto;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    if (!produto.emPromocao) {
      return Text(Formatters.currency(produto.preco), style: base);
    }
    final cores = Theme.of(context).extension<StockStatusColors>()!;
    return Semantics(
      label: 'Em promoção: ${Formatters.currency(produto.precoVenda)}, '
          'antes ${Formatters.currency(produto.preco)}',
      excludeSemantics: true,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            Formatters.currency(produto.precoVenda),
            style: base?.copyWith(fontWeight: FontWeight.w700, color: cores.ok),
          ),
          Text(
            Formatters.currency(produto.preco),
            style: base?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          StatusBadge(
            label: 'Promoção -${produto.promocaoPercentual}%',
            color: cores.ok,
            icon: Icons.local_offer_outlined,
          ),
        ],
      ),
    );
  }
}
