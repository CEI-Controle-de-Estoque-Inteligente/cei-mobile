import 'package:flutter/material.dart';

/// Mensagens de sucesso/erro padronizadas (C1.6).
abstract final class AppFeedback {
  static void success(BuildContext context, String message, {SnackBarAction? action}) {
    _show(context, message, icon: Icons.check_circle_outline, action: action);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, icon: Icons.error_outline, isError: true);
  }

  static void info(BuildContext context, String message, {SnackBarAction? action}) {
    _show(context, message, icon: Icons.info_outline, action: action);
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    bool isError = false,
    SnackBarAction? action,
  }) {
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: isError ? colors.error : null,
          action: action,
          duration: Duration(seconds: action != null ? 6 : 4),
          content: Row(
            children: [
              Icon(icon, color: isError ? colors.onError : colors.onInverseSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: isError ? colors.onError : colors.onInverseSurface),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
