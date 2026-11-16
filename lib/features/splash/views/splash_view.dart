import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/cei_logo.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

/// Exibida enquanto a sessão é restaurada. O roteador sai daqui sozinho
/// quando o estado da sessão é conhecido.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();

    return Scaffold(
      body: SafeArea(
        child: session.status == SessionStatus.erro
            ? ErrorView(
                message: session.erro ?? 'Não foi possível carregar seus dados.',
                onRetry: session.recarregarPerfil,
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(tag: 'cei-logo', child: CeiLogo(size: 96)),
                    SizedBox(height: 32),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
      ),
    );
  }
}
