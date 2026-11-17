import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/produto.dart';
import '../../../shared/descontos_context.dart';
import '../../../shared/widgets/cei_button.dart';

/// Bloco de promoção na tela do produto (somente gerente).
/// Mostra a promoção ativa ou a sugestão da tabela de descontos.
class PromocaoCard extends StatelessWidget {
  const PromocaoCard({
    super.key,
    required this.produto,
    required this.salvando,
    required this.onAplicar,
  });

  final Produto produto;
  final bool salvando;

  /// Recebe o percentual escolhido (0 = encerrar promoção).
  final ValueChanged<int> onAplicar;

  Future<void> _abrirDialogo(BuildContext context, int? sugestao) async {
    final percentual = await showDialog<int>(
      context: context,
      builder: (_) => _PromocaoDialog(produto: produto, sugestao: sugestao),
    );
    if (percentual != null) onAplicar(percentual);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sugestao = produto.descontoSugerido(tabela: tabelaDescontosDe(context));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Promoção', style: textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (produto.emPromocao) ...[
              Text(
                '${produto.promocaoPercentual}% de desconto: '
                '${Formatters.currency(produto.precoVenda)} (antes ${Formatters.currency(produto.preco)}). '
                'As vendas já usam este preço.',
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  CeiButton(
                    label: 'Alterar desconto',
                    icon: Icons.edit_outlined,
                    variant: CeiButtonVariant.secondary,
                    expand: false,
                    onPressed: salvando ? null : () => _abrirDialogo(context, produto.promocaoPercentual),
                  ),
                  CeiButton(
                    label: 'Encerrar promoção',
                    icon: Icons.close,
                    variant: CeiButtonVariant.text,
                    expand: false,
                    isLoading: salvando,
                    onPressed: () => onAplicar(0),
                  ),
                ],
              ),
            ] else ...[
              Text(
                sugestao != null
                    ? 'Vence em ${produto.diasParaVencer()} dia(s). A tabela de descontos sugere $sugestao% '
                          '(${Formatters.currency(produto.precoComDesconto(sugestao))}).'
                    : 'Sem promoção. Você pode aplicar um desconto a qualquer momento.',
              ),
              const SizedBox(height: AppSpacing.md),
              CeiButton(
                label: sugestao != null ? 'Aplicar $sugestao% de desconto' : 'Aplicar desconto',
                icon: Icons.sell_outlined,
                isLoading: salvando,
                onPressed: () => _abrirDialogo(context, sugestao),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromocaoDialog extends StatefulWidget {
  const _PromocaoDialog({required this.produto, this.sugestao});

  final Produto produto;
  final int? sugestao;

  @override
  State<_PromocaoDialog> createState() => _PromocaoDialogState();
}

class _PromocaoDialogState extends State<_PromocaoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.sugestao?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _valor => int.tryParse(_controller.text.trim());

  String? _validar(String? texto) {
    final v = int.tryParse(texto?.trim() ?? '');
    if (v == null) return 'Informe o percentual';
    if (v < 1 || v > 90) return 'Use um valor de 1% a 90%';
    return null;
  }

  void _confirmar() {
    if (_formKey.currentState?.validate() ?? false) Navigator.of(context).pop(_valor);
  }

  @override
  Widget build(BuildContext context) {
    final v = _valor;
    final previa = v != null && v >= 1 && v <= 90
        ? 'Novo preço: ${Formatters.currency(widget.produto.precoComDesconto(v))} '
              '(antes ${Formatters.currency(widget.produto.preco)})'
        : 'Preço atual: ${Formatters.currency(widget.produto.preco)}';

    return AlertDialog(
      title: const Text('Aplicar desconto'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.produto.nome, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              decoration: const InputDecoration(labelText: 'Desconto', suffixText: '%'),
              validator: _validar,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _confirmar(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(previa),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirmar, child: const Text('Aplicar')),
      ],
    );
  }
}
