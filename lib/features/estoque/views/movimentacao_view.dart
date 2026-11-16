import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/movimentacao.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/sync_service.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../viewmodels/movimentacao_viewmodel.dart';

/// Registro simplificado de entradas e saídas.
class MovimentacaoView extends StatelessWidget {
  const MovimentacaoView({super.key, required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MovimentacaoViewModel(context.read<ProdutoRepository>(), produto),
      child: const _MovimentacaoForm(),
    );
  }
}

class _MovimentacaoForm extends StatefulWidget {
  const _MovimentacaoForm();

  @override
  State<_MovimentacaoForm> createState() => _MovimentacaoFormState();
}

class _MovimentacaoFormState extends State<_MovimentacaoForm> {
  final _formKey = GlobalKey<FormState>();
  final _quantidade = TextEditingController();
  final _observacao = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _quantidade.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<MovimentacaoViewModel>();
    final sync = context.read<SyncService>();
    final resultado = await vm.salvar(_observacao.text);
    if (!mounted) return;
    if (resultado == null) {
      AppFeedback.error(context, vm.erro ?? 'Não foi possível registrar.');
      return;
    }
    setState(() => _dirty = false);
    if (resultado.pendente) {
      await sync.carregar();
      if (!mounted) return;
      AppFeedback.info(context, 'Sem conexão: movimentação salva e será enviada automaticamente.');
    } else {
      AppFeedback.success(context, 'Movimentação registrada. Novo saldo: ${resultado.valor.quantidade}.');
    }
    context.pop(resultado.valor);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MovimentacaoViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final saldo = vm.saldoPrevisto;

    return UnsavedChangesGuard(
      hasChanges: _dirty && !vm.salvando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Movimentar estoque')),
        body: ResponsiveBody(
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(vm.produto.nome, style: textTheme.titleLarge),
                Text('Saldo atual: ${vm.produto.quantidade} un.', style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                SegmentedButton<TipoMovimentacao>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: TipoMovimentacao.entrada, label: Text('Entrada')),
                    ButtonSegment(value: TipoMovimentacao.saida, label: Text('Saída')),
                    ButtonSegment(value: TipoMovimentacao.ajuste, label: Text('Ajuste')),
                  ],
                  selected: {vm.tipo},
                  onSelectionChanged: (s) {
                    vm.alterarTipo(s.first);
                    _formKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  switch (vm.tipo) {
                    TipoMovimentacao.entrada => 'Compra ou reposição: soma ao estoque.',
                    TipoMovimentacao.saida => 'Perda, avaria, uso interno ou devolução ao fornecedor.',
                    _ => 'Contagem de inventário: informe o saldo real encontrado.',
                  },
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                CeiTextField(
                  controller: _quantidade,
                  label: vm.tipo == TipoMovimentacao.ajuste ? 'Saldo contado' : 'Quantidade',
                  prefixIcon: Icons.numbers,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: vm.validarQuantidade,
                  onChanged: vm.alterarQuantidade,
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _observacao,
                  label: 'Observação (opcional)',
                  hint: 'Ex.: NF 1234, produto avariado',
                  prefixIcon: Icons.notes,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_outlined),
                    title: const Text('Saldo após a operação'),
                    trailing: Text(
                      '$saldo un.',
                      style: textTheme.titleMedium?.copyWith(
                        color: saldo < 0 ? Theme.of(context).colorScheme.error : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CeiButton(
                  label: 'Registrar',
                  icon: Icons.check,
                  isLoading: vm.salvando,
                  onPressed: _salvar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
