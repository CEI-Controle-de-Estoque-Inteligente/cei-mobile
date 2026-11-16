import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'cei_button.dart';

/// Estado "Aguardando" padronizado (C5.3).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: message ?? 'Carregando',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado "Erro" com mensagem amigável e "Tentar novamente" (C5.3).
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _CenteredMessage(
      icon: Icons.cloud_off_outlined,
      iconColor: colors.error,
      title: 'Ops! Algo não saiu como esperado',
      message: message,
      action: onRetry == null
          ? null
          : CeiButton(
              label: 'Tentar novamente',
              icon: Icons.refresh,
              variant: CeiButtonVariant.secondary,
              onPressed: onRetry,
            ),
    );
  }
}

/// Estado "Vazio" (ex.: nenhum resultado na busca).
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.outline,
      title: title,
      message: message,
      action: action,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Rolável para não estourar em telas pequenas/fonte ampliada (C1.4).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 56, color: iconColor),
                    const SizedBox(height: AppSpacing.md),
                    Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(message!, style: textTheme.bodyMedium, textAlign: TextAlign.center),
                    ],
                    if (action != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
