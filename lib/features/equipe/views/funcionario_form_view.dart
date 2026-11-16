import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/equipe_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../viewmodels/equipe_viewmodel.dart';

class FuncionarioFormView extends StatelessWidget {
  const FuncionarioFormView({super.key, required this.funcionario});

  final Perfil funcionario;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => FuncionarioFormViewModel(context.read<EquipeRepository>(), funcionario),
      child: const _FuncionarioForm(),
    );
  }
}

class _FuncionarioForm extends StatelessWidget {
  const _FuncionarioForm();

  Future<void> _salvar(BuildContext context) async {
    final vm = context.read<FuncionarioFormViewModel>();
    if (!vm.editado.ativo && vm.original.ativo) {
      final ok = await showConfirmDialog(
        context,
        title: 'Desativar acesso?',
        message: '${vm.original.nome} não conseguirá mais entrar no app até ser reativado(a).',
        confirmLabel: 'Desativar',
        destructive: true,
      );
      if (!ok) return;
    }
    final salvo = await vm.salvar();
    if (!context.mounted) return;
    if (salvo == null) {
      AppFeedback.error(context, vm.erro ?? 'Não foi possível salvar.');
      return;
    }
    AppFeedback.success(context, 'Dados de ${salvo.nome} atualizados.');
    context.pop(salvo);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FuncionarioFormViewModel>();
    final f = vm.editado;
    final textTheme = Theme.of(context).textTheme;

    return UnsavedChangesGuard(
      hasChanges: vm.alterado && !vm.salvando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Editar funcionário')),
        body: ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: UserAvatar(iniciais: f.iniciais, nome: f.nome, radius: 36)),
              const SizedBox(height: AppSpacing.sm),
              Text(f.nome, style: textTheme.titleLarge, textAlign: TextAlign.center),
              Text(f.email, style: textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<Cargo>(
                initialValue: f.cargo,
                decoration: const InputDecoration(labelText: 'Cargo', prefixIcon: Icon(Icons.badge_outlined)),
                items: [for (final c in Cargo.values) DropdownMenuItem(value: c, child: Text(c.label))],
                onChanged: (c) => vm.alterar(cargo: c),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(_descricaoCargo(f.cargo), style: textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<Turno>(
                initialValue: f.turno,
                decoration: const InputDecoration(labelText: 'Turno', prefixIcon: Icon(Icons.schedule)),
                items: [for (final t in Turno.values) DropdownMenuItem(value: t, child: Text(t.label))],
                onChanged: (t) => vm.alterar(turno: t),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<StatusFuncionario>(
                initialValue: f.status,
                decoration: const InputDecoration(labelText: 'Situação', prefixIcon: Icon(Icons.event_note_outlined)),
                items: [
                  for (final s in StatusFuncionario.values) DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (s) => vm.alterar(status: s),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                title: const Text('Acesso ao aplicativo'),
                subtitle: Text(f.ativo ? 'Pode entrar no CEI' : 'Acesso bloqueado'),
                value: f.ativo,
                onChanged: (v) => vm.alterar(ativo: v),
              ),
              const SizedBox(height: AppSpacing.lg),
              CeiButton(
                label: 'Salvar',
                icon: Icons.check,
                isLoading: vm.salvando,
                onPressed: vm.alterado ? () => _salvar(context) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _descricaoCargo(Cargo cargo) => switch (cargo) {
    Cargo.gerente => 'Acesso total, incluindo equipe e vendas de todos.',
    Cargo.vendedor => 'Dashboard, consulta de estoque, vendas próprias e assistente.',
    Cargo.caixa => 'Dashboard, consulta de estoque, vendas próprias e assistente.',
    Cargo.estoquista => 'Dashboard, cadastro de produtos, entradas/saídas e assistente.',
  };
}
