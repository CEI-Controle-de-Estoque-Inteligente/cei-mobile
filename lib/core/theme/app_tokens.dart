import 'package:flutter/material.dart';

/// Tokens do Design System CEI.
/// Nenhuma tela deve usar valores "soltos": tudo vem daqui ou do Theme.
abstract final class AppColors {
  // Identidade CEI (baseada no logotipo: azul-ciano + cinza claro)
  static const Color brand = Color(0xFF2BA8C8);
  static const Color brandDark = Color(0xFF1C7F99);
  static const Color accent = Color(0xFFF5A623);

  // Semânticas de estoque
  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFE8A317);
  static const Color danger = Color(0xFFD64545);

  // Superfícies
  static const Color lightBackground = Color(0xFFF4F7F9);
  static const Color darkBackground = Color(0xFF0F1A1F);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

abstract final class AppElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
}

abstract final class AppSizes {
  /// Alvo de toque mínimo (acessibilidade - C1.5).
  static const double minTouchTarget = 48;
  static const double maxContentWidth = 480;
}
