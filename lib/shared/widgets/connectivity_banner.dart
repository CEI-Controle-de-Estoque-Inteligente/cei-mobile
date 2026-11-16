import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/repositories/sync_service.dart';

/// Faixa que informa o estado da conexão e operações pendentes (C4.4).
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, this.onTapPendentes});

  final VoidCallback? onTapPendentes;

  @override
  Widget build(BuildContext context) {
    final online = context.select<ConnectivityService, bool>((c) => c.isOnline);
    final pendentes = context.select<SyncService, int>((s) => s.quantidade);
    final sincronizando = context.select<SyncService, bool>((s) => s.sincronizando);
    final colors = Theme.of(context).colorScheme;

    final String? texto;
    final IconData icon;
    if (!online) {
      texto = pendentes > 0
          ? 'Sem conexão • $pendentes operação(ões) aguardando envio'
          : 'Sem conexão • exibindo dados salvos no aparelho';
      icon = Icons.wifi_off;
    } else if (sincronizando) {
      texto = 'Sincronizando operações pendentes...';
      icon = Icons.sync;
    } else if (pendentes > 0) {
      texto = '$pendentes operação(ões) pendente(s) • toque para revisar';
      icon = Icons.sync_problem;
    } else {
      texto = null;
      icon = Icons.wifi;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: texto == null
          ? const SizedBox(width: double.infinity)
          : Material(
              color: online ? colors.tertiaryContainer : colors.errorContainer,
              child: InkWell(
                onTap: pendentes > 0 ? onTapPendentes : null,
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: online ? colors.onTertiaryContainer : colors.onErrorContainer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            texto,
                            style: TextStyle(color: online ? colors.onTertiaryContainer : colors.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
