import 'package:flutter/material.dart';

enum CeiButtonVariant { primary, secondary, text }

/// Botão padrão do app, com estado de carregamento embutido (C1.3 / C1.6).
/// Por padrão ocupa toda a largura disponível ([expand]).
class CeiButton extends StatelessWidget {
  const CeiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = CeiButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final CeiButtonVariant variant;
  final bool expand;

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

    final button = switch (variant) {
      CeiButtonVariant.primary => FilledButton(onPressed: action, child: child),
      CeiButtonVariant.secondary => OutlinedButton(onPressed: action, child: child),
      CeiButtonVariant.text => TextButton(onPressed: action, child: child),
    };

    return Semantics(
      button: true,
      enabled: action != null,
      label: isLoading ? '$label, carregando' : label,
      excludeSemantics: true,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}
