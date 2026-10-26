import 'package:cei_mobile/data/local/preferences_service.dart';
import 'package:cei_mobile/features/settings/viewmodels/theme_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tema padrão é o do sistema', () async {
    final vm = ThemeViewModel(await PreferencesService.create());
    expect(vm.themeMode, ThemeMode.system);
  });

  test('tema escolhido é persistido', () async {
    final vm = ThemeViewModel(await PreferencesService.create());
    await vm.setThemeMode(ThemeMode.dark);

    final reopened = ThemeViewModel(await PreferencesService.create());
    expect(reopened.themeMode, ThemeMode.dark);
  });
}
