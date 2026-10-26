import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Acesso centralizado às preferências do usuário (C4.5).
/// Tokens de sessão NÃO ficam aqui: irão para flutter_secure_storage (Sprint 1).
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'theme_mode';

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  ThemeMode readThemeMode() {
    final stored = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }
}
