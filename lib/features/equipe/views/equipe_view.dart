import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/equipe_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/equipe_viewmodel.dart';

/// Gestão de equipe e turnos (somente Gerente - RN001 Funcionários).
class EquipeView extends StatelessWidget {
  const EquipeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => EquipeViewModel(context.read<EquipeRepository>())..carregar(),
      child: const _EquipeBody(),
    );
  }
}

class _EquipeBody extends StatelessWidget {
  const _EquipeBody();

  Future<void> _editar(BuildContext context, Perfil funcionario) async {
    final vm = context.read<EquipeViewModel>();
    final atualizado = await context.push<Perfil>(AppRoutes.funcionario(funcionario.id), extra: funcionario);
    if (atualizado != null) vm.atualizado(atualizado);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EquipeViewModel>();
    final eu = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    final codigo = eu?.empresa?.codigoConvite;

    final Widget body;
    if (vm.carregando) {
      body = const LoadingView();
    } else if (vm.erro != null) {
      body = ErrorView(message: vm.erro!, onRetry: vm.carregar);
    } else {
      final equipe = vm.equipe;
      body = RefreshIndicator(
        onRefresh: vm.carregar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
          itemCount: equipe.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (codigo != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.key_outlined),
                        title: Text('Código da empresa: $codigo'),
                        subtitle: const Text('Funcionários usam este código ao criar a conta.'),
                        trailing: IconButton(
                          tooltip: 'Copiar código',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: codigo));
                            if (context.mounted) AppFeedback.success(context, 'Código copiado!');
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  SearchField(hint: 'Buscar por nome ou cargo', onChanged: vm.buscar),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${vm.ativos} ativo(s) de ${equipe.length}', style: Theme.of(context).textTheme.bodySmall),
                  if (equipe.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text('Nenhum funcionário encontrado.', textAlign: TextAlign.center),
                    ),
                ],
              );
            }
            final f = equipe[i - 1];
            return _FuncionarioCard(
              key: ValueKey(f.id),
              funcionario: f,
              souEu: f.id == eu?.id,
              onTap: f.id == eu?.id ? null : () => _editar(context, f),
            );
          },
        ),
      );
    }

    return Scaffold(appBar: AppBar(title: const Text('Equipe e turnos')), body: body);
  }
}

class _FuncionarioCard extends StatelessWidget {
  const _FuncionarioCard({super.key, required this.funcionario, required this.souEu, this.onTap});

  final Perfil funcionario;
  final bool souEu;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = funcionario;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: UserAvatar(iniciais: f.iniciais, nome: f.nome),
        title: Text(souEu ? '${f.nome} (você)' : f.nome),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${f.cargo.label} • ${f.turno.label}'),
              if (f.ativo)
                StatusBadge.funcionario(context, f.status)
              else
                StatusBadge(label: 'Desativado', color: Theme.of(context).colorScheme.outline),
            ],
          ),
        ),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}
