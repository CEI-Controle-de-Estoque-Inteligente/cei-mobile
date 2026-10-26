import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/local/preferences_service.dart';
import 'data/repositories/auth_repository.dart';
import 'features/auth/viewmodels/session_viewmodel.dart';
import 'features/settings/viewmodels/theme_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await PreferencesService.create();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeViewModel(preferences)),
        ChangeNotifierProvider(
          create: (_) => SessionViewModel(PreliminaryAuthRepository()),
        ),
      ],
      child: const CeiApp(),
    ),
  );
}
