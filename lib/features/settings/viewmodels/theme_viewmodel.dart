import 'package:flutter/material.dart';

import '../../../data/local/preferences_service.dart';

/// Controla o tema (Claro / Escuro / Sistema) com persistência (C1.2).
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel(this._preferences) : _themeMode = _preferences.readThemeMode();

  final PreferencesService _preferences;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _preferences.saveThemeMode(mode);
  }
}
