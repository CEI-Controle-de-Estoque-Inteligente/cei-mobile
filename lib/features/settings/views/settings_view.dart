import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/sync_service.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _sincronizar(BuildContext context) async {
    final enviadas = await context.read<SyncService>().sincronizar();
    if (!context.mounted) return;
    AppFeedback.info(context, enviadas == 0 ? 'Nada foi enviado agora.' : '$enviadas operação(ões) enviada(s).');
  }

  Future<void> _popularDemo(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Carregar dados de demonstração?',
      message: 'Serão criados 25 produtos de exemplo e vendas dos últimos 7 dias. '
          'Só funciona enquanto a empresa não tem produtos cadastrados.',
      confirmLabel: 'Carregar',
    );
    if (!ok || !context.mounted) return;
    try {
      final total = await context.read<ProdutoRepository>().popularDemo();
      if (context.mounted) AppFeedback.success(context, '$total produtos de demonstração criados.');
    } on AppException catch (e) {
      if (context.mounted) AppFeedback.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    final sync = context.watch<SyncService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionHeader(title: 'Aparência'),
          const Align(alignment: Alignment.centerLeft, child: ThemeModeSelector()),
          const SectionHeader(title: 'Sincronização'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Operações pendentes'),
                  subtitle: Text(
                    sync.quantidade == 0
                        ? 'Tudo sincronizado'
                        : '${sync.quantidade} operação(ões) aguardando envio',
                  ),
                  trailing: sync.sincronizando
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.pendencias),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Sincronizar agora'),
                  enabled: !sync.sincronizando && sync.quantidade > 0,
                  onTap: () => _sincronizar(context),
                ),
              ],
            ),
          ),
          if (perfil?.pode(Modulo.equipe) ?? false) ...[
            const SectionHeader(title: 'Empresa'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Código para funcionários'),
                    subtitle: Text(perfil?.empresa?.codigoConvite ?? '-'),
                    onTap: () => context.go(AppRoutes.equipe),
                  ),
                  ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: const Text('Tabela de descontos'),
                    subtitle: const Text('Quanto sugerir para produtos perto do vencimento'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.descontos),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dataset_outlined),
                    title: const Text('Carregar dados de demonstração'),
                    subtitle: const Text('Produtos e vendas de exemplo para testar o app'),
                    onTap: () => _popularDemo(context),
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader(title: 'Sobre'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('CEI Mobile 1.0.0'),
                  subtitle: Text('Projeto Integrador - CST em Análise e Desenvolvimento de Sistemas - UniSENAI Jaraguá do Sul'),
                ),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacidade (LGPD)'),
                  subtitle: Text(
                    'Seus dados são usados apenas para o funcionamento do CEI. Ao sair da conta, '
                    'os dados salvos no aparelho são apagados.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
