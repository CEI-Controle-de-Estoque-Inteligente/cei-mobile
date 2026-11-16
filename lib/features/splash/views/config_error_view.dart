import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/local/preferences_service.dart';
import '../../../shared/widgets/cei_logo.dart';
import '../../../shared/widgets/responsive_body.dart';

/// Exibida quando o app é executado sem as chaves do Supabase.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.preferences});

  final PreferencesService preferences;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: preferences.readThemeMode(),
      home: Scaffold(
        body: ResponsiveBody(
          center: true,
          child: Column(
            children: [
              const CeiLogo(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Configuração necessária',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'As chaves do Supabase não foram informadas.\n\n'
                '1. Copie o arquivo .env.example para .env e preencha SUPABASE_URL e SUPABASE_KEY.\n'
                '2. Rode: flutter run --dart-define-from-file=.env',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
