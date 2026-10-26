import 'package:flutter/material.dart';

enum CeiButtonVariant { primary, secondary }

/// Botão padrão do app, com estado de carregamento embutido (C1.3 / C1.6).
class CeiButton extends StatelessWidget {
  const CeiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = CeiButtonVariant.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final CeiButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final action = isLoading ? null : onPressed;
    final child = isLoading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return Semantics(
      button: true,
      label: isLoading ? '$label, carregando' : label,
      excludeSemantics: true,
      child: switch (variant) {
        CeiButtonVariant.primary => FilledButton(
            onPressed: action,
            child: child,
          ),
        CeiButtonVariant.secondary => OutlinedButton(
            onPressed: action,
            child: child,
          ),
      },
    );
  }
}
