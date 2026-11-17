import 'package:cei_mobile/core/theme/app_theme.dart';
import 'package:cei_mobile/shared/widgets/cei_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _emCaixa(double altura, {double size = 96}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 293, height: altura, child: CeiLogo(size: size)),
    ),
  ),
);

void main() {
  testWidgets('logo diminui sem estourar quando falta altura (animação Hero)', (tester) async {
    for (final altura in [158.0, 120.0, 80.0]) {
      await tester.pumpWidget(_emCaixa(altura));
      expect(tester.takeException(), isNull, reason: 'overflow com altura $altura');
    }
  });

  testWidgets('logo mantém o tamanho normal quando há espaço', (tester) async {
    await tester.pumpWidget(_emCaixa(600, size: 72));
    expect(tester.takeException(), isNull);
    final quadrado = tester.getSize(
      find.descendant(of: find.byType(CeiLogo), matching: find.byType(Container)).first,
    );
    expect(quadrado, const Size.square(72));
  });
}
