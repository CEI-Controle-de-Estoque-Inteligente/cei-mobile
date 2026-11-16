import 'package:flutter/material.dart';

import 'confirm_dialog.dart';

/// Protege formulários de cadastro/edição: sair com alterações não salvas
/// (botão voltar, gesto ou seta da AppBar) pede confirmação (C2.7).
/// Usa PopScope + onPopInvokedWithResult (WillPopScope está descontinuado).
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({super.key, required this.hasChanges, required this.child});

  final bool hasChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final sair = await showConfirmDialog(
          context,
          title: 'Descartar alterações?',
          message: 'Você tem alterações que não foram salvas. Deseja sair mesmo assim?',
          confirmLabel: 'Descartar',
          cancelLabel: 'Continuar editando',
          destructive: true,
        );
        if (sair && navigator.mounted) navigator.pop(result);
      },
      child: child,
    );
  }
}
