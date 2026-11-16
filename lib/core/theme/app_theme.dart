import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Cores semânticas de status de estoque, disponíveis nos dois temas.
@immutable
class StockStatusColors extends ThemeExtension<StockStatusColors> {
  const StockStatusColors({
    required this.ok,
    required this.low,
    required this.critical,
  });

  final Color ok;
  final Color low;
  final Color critical;

  @override
  StockStatusColors copyWith({Color? ok, Color? low, Color? critical}) {
    return StockStatusColors(
      ok: ok ?? this.ok,
      low: low ?? this.low,
      critical: critical ?? this.critical,
    );
  }

  @override
  StockStatusColors lerp(ThemeExtension<StockStatusColors>? other, double t) {
    if (other is! StockStatusColors) return this;
    return StockStatusColors(
      ok: Color.lerp(ok, other.ok, t)!,
      low: Color.lerp(low, other.low, t)!,
      critical: Color.lerp(critical, other.critical, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
      surface: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      error: AppColors.danger,
    );

    final baseText = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final textTheme = baseText.copyWith(
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: AppElevation.none,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: const CardThemeData(
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTouchTarget),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      extensions: const [
        StockStatusColors(
          ok: AppColors.success,
          low: AppColors.warning,
          critical: AppColors.danger,
        ),
      ],
    );
  }
}
