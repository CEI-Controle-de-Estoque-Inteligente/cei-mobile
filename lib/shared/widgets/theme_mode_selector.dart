import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/settings/viewmodels/theme_viewmodel.dart';

/// Seletor Claro / Escuro / Sistema (C1.2). Reutilizado no login e nas
/// configurações. Em telas estreitas exibe apenas ícones (C1.4).
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  static const double _compactBreakpoint = 340;

  static const List<(ThemeMode, IconData, String)> _options = [
    (ThemeMode.light, Icons.light_mode_outlined, 'Claro'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Escuro'),
    (ThemeMode.system, Icons.brightness_auto_outlined, 'Sistema'),
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ThemeViewModel>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;

        return SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: [
            for (final (mode, icon, label) in _options)
              ButtonSegment(
                value: mode,
                icon: Icon(icon),
                label: compact ? null : Text(label),
                tooltip: 'Tema: $label',
              ),
          ],
          selected: {viewModel.themeMode},
          onSelectionChanged: (selection) =>
              viewModel.setThemeMode(selection.first),
        );
      },
    );
  }
}
