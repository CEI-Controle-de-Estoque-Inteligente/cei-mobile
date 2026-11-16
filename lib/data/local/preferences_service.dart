import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do usuário (C4.5). Tokens de sessão NÃO ficam aqui: vão
/// para o armazenamento seguro (ver SecureSessionStorage).
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'theme_mode';
  static const String _perfilKey = 'perfil_cache';
  static const String _onboardingKey = 'onboarding_visto';

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

  bool get onboardingVisto => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> marcarOnboardingVisto() => _prefs.setBool(_onboardingKey, true);

  /// Último perfil carregado: permite abrir o app sem internet (C4.4).
  Map<String, dynamic>? readPerfilCache() {
    final raw = _prefs.getString(_perfilKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> savePerfilCache(Map<String, dynamic> json) =>
      _prefs.setString(_perfilKey, jsonEncode(json));

  Future<void> clearPerfilCache() => _prefs.remove(_perfilKey);
}
