import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/sync_service.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/perfil_viewmodel.dart';

class PerfilView extends StatelessWidget {
  const PerfilView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PerfilViewModel(context.read<AuthRepository>(), context.read<SessionViewModel>()),
      child: const _PerfilBody(),
    );
  }
}

class _PerfilBody extends StatelessWidget {
  const _PerfilBody();

  Future<void> _editarNome(BuildContext context, Perfil perfil) async {
    final vm = context.read<PerfilViewModel>();
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => _EditarNomeDialog(nomeAtual: perfil.nome),
    );
    if (nome == null || nome.trim() == perfil.nome) return;
    final ok = await vm.atualizarNome(nome);
    if (!context.mounted) return;
    ok ? AppFeedback.success(context, 'Nome atualizado.') : AppFeedback.error(context, vm.erro!);
  }

  Future<void> _sair(BuildContext context) async {
    final vm = context.read<PerfilViewModel>();
    final pendentes = context.read<SyncService>().quantidade;
    final ok = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message: pendentes > 0
          ? 'Atenção: há $pendentes operação(ões) ainda não enviadas. Elas serão perdidas se você sair agora.'
          : 'Você precisará entrar novamente com seu e-mail e senha.',
      confirmLabel: 'Sair',
      destructive: pendentes > 0,
    );
    if (ok) await vm.sair();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    final vm = context.watch<PerfilViewModel>();
    if (perfil == null) return const Scaffold(body: LoadingView());
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Center(child: UserAvatar(iniciais: perfil.iniciais, nome: perfil.nome, radius: 40)),
          const SizedBox(height: AppSpacing.md),
          Text(perfil.nome, style: textTheme.headlineSmall, textAlign: TextAlign.center),
          Text(perfil.email, style: textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Center(child: StatusBadge.funcionario(context, perfil.status)),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Cargo'),
                  subtitle: Text('${perfil.cargo.label} • turno ${perfil.turno.label.toLowerCase()}'),
                ),
                ListTile(
                  leading: const Icon(Icons.store_outlined),
                  title: const Text('Empresa'),
                  subtitle: Text(perfil.empresa?.nome ?? '-'),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar nome'),
                  trailing: vm.salvando
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: vm.salvando ? null : () => _editarNome(context, perfil),
                ),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Alterar senha'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.alterarSenha),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configurações'),
                  subtitle: const Text('Tema, sincronização e sobre'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.configuracoes),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CeiButton(
            label: 'Sair da conta',
            icon: Icons.logout,
            variant: CeiButtonVariant.secondary,
            onPressed: () => _sair(context),
          ),
        ],
      ),
    );
  }
}

class _EditarNomeDialog extends StatefulWidget {
  const _EditarNomeDialog({required this.nomeAtual});

  final String nomeAtual;

  @override
  State<_EditarNomeDialog> createState() => _EditarNomeDialogState();
}

class _EditarNomeDialogState extends State<_EditarNomeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(text: widget.nomeAtual);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState?.validate() ?? false) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar nome'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome'),
          validator: Validators.name,
          onFieldSubmitted: (_) => _salvar(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
