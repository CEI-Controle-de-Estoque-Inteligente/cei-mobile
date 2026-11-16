import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/operacao_pendente.dart';
import '../../../data/repositories/sync_service.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/state_views.dart';

/// Fila offline: o usuário vê o que falta enviar e resolve rejeições.
class PendenciasView extends StatelessWidget {
  const PendenciasView({super.key});

  Future<void> _descartar(BuildContext context, OperacaoPendente op) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Descartar operação?',
      message: '"${op.descricao}" não será enviada ao servidor.',
      confirmLabel: 'Descartar',
      destructive: true,
    );
    if (ok && context.mounted) await context.read<SyncService>().descartar(op);
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final online = context.select<ConnectivityService, bool>((c) => c.isOnline);
    final itens = sync.itens;

    return Scaffold(
      appBar: AppBar(title: const Text('Operações pendentes')),
      body: itens.isEmpty
          ? const EmptyView(
              icon: Icons.cloud_done_outlined,
              title: 'Tudo sincronizado',
              message: 'Vendas e movimentações feitas sem internet aparecem aqui até serem enviadas.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: itens.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final op = itens[i];
                return Card(
                  key: ValueKey(op.id),
                  child: ListTile(
                    leading: Icon(op.erro == null ? Icons.schedule : Icons.error_outline,
                        color: op.erro == null ? null : Theme.of(context).colorScheme.error),
                    title: Text(op.descricao),
                    subtitle: Text(
                      op.erro == null
                          ? 'Registrada em ${Formatters.dateTime(op.criadaEm)}'
                          : 'Rejeitada pelo servidor: ${op.erro}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Descartar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _descartar(context, op),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: itens.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: CeiButton(
                  label: online ? 'Enviar agora' : 'Sem conexão',
                  icon: Icons.cloud_upload_outlined,
                  isLoading: sync.sincronizando,
                  onPressed: online
                      ? () async {
                          final enviadas = await sync.sincronizar();
                          if (context.mounted) AppFeedback.info(context, '$enviadas operação(ões) enviada(s).');
                        }
                      : null,
                ),
              ),
            ),
    );
  }
}
