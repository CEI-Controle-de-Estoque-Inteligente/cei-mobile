import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

/// Acesso negado por perfil (critério de aceitação do módulo Funcionários).
class SemPermissaoView extends StatelessWidget {
  const SemPermissaoView({super.key});

  @override
  Widget build(BuildContext context) {
    final cargo = context.watch<SessionViewModel>().perfil?.cargo.label ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso negado')),
      body: EmptyView(
        icon: Icons.lock_outline,
        title: 'Permissão insuficiente',
        message: 'Seu perfil ($cargo) não tem acesso a este módulo. '
            'Fale com o gerente se precisar de acesso.',
        action: CeiButton(
          label: 'Voltar ao início',
          icon: Icons.home_outlined,
          onPressed: () => context.go(AppRoutes.inicio),
        ),
      ),
    );
  }
}
