import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/viewmodels/session_viewmodel.dart';
import 'features/settings/viewmodels/theme_viewmodel.dart';

class CeiApp extends StatefulWidget {
  const CeiApp({super.key});

  @override
  State<CeiApp> createState() => _CeiAppState();
}

class _CeiAppState extends State<CeiApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(context.read<SessionViewModel>());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<ThemeViewModel, ThemeMode>((vm) => vm.themeMode);

    return MaterialApp.router(
      title: 'CEI - Controle de Estoque Inteligente',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
