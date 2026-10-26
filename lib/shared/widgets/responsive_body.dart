import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Corpo de tela rolável, centralizado e com largura máxima.
/// Evita overflow em telas pequenas, paisagem e com teclado aberto (C1.4).
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.center = false});

  final Widget child;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: center
                    ? math.max(0, constraints.maxHeight - AppSpacing.lg * 2)
                    : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxContentWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
