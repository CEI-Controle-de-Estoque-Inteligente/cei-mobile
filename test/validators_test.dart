import 'package:cei_mobile/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('rejeita vazio', () {
      expect(Validators.email(''), 'Informe o e-mail');
      expect(Validators.email(null), 'Informe o e-mail');
    });

    test('rejeita formato inválido', () {
      expect(Validators.email('joao@'), isNotNull);
      expect(Validators.email('joao.com'), isNotNull);
    });

    test('aceita e-mail válido', () {
      expect(Validators.email('joao@cei.com.br'), isNull);
    });
  });

  group('Validators.password', () {
    test('exige mínimo de 8 caracteres', () {
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
    });
  });
}
