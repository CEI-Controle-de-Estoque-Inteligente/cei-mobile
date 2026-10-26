import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/theme_mode_selector.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aparência', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            const ThemeModeSelector(),
          ],
        ),
      ),
    );
  }
}
