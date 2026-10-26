import 'package:cei_mobile/core/theme/app_theme.dart';
import 'package:cei_mobile/data/local/preferences_service.dart';
import 'package:cei_mobile/data/repositories/auth_repository.dart';
import 'package:cei_mobile/features/auth/viewmodels/session_viewmodel.dart';
import 'package:cei_mobile/features/auth/views/login_view.dart';
import 'package:cei_mobile/features/settings/viewmodels/theme_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpLogin(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await PreferencesService.create();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeViewModel(preferences)),
        ChangeNotifierProvider(
          create: (_) => SessionViewModel(PreliminaryAuthRepository()),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const LoginView()),
    ),
  );
}

void main() {
  testWidgets('login exibe erros de validação com campos vazios', (
    tester,
  ) async {
    await _pumpLogin(tester);

    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe o e-mail'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
  });

  testWidgets('login não estoura em tela pequena (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester);
    expect(tester.takeException(), isNull);
  });
}
