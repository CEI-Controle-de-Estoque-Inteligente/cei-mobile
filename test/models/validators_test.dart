import 'package:cei_mobile/core/utils/formatters.dart';
import 'package:cei_mobile/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

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

  group('Senhas', () {
    test('mínimo de 8 caracteres', () {
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
    });

    test('senha forte exige letras e números', () {
      expect(Validators.strongPassword('abcdefgh'), isNotNull);
      expect(Validators.strongPassword('12345678'), isNotNull);
      expect(Validators.strongPassword('abcd1234'), isNull);
    });

    test('confirmação precisa ser igual', () {
      final validar = Validators.confirmPassword(() => 'abcd1234');
      expect(validar('abcd1235'), 'As senhas não coincidem');
      expect(validar('abcd1234'), isNull);
    });
  });

  group('CNPJ', () {
    test('valida dígitos verificadores', () {
      expect(Validators.isValidCnpj('11222333000181'), isTrue);
      expect(Validators.isValidCnpj('11222333000182'), isFalse);
      expect(Validators.isValidCnpj('11111111111111'), isFalse);
    });

    test('é opcional, mas se informado precisa ser válido', () {
      expect(Validators.optionalCnpj(''), isNull);
      expect(Validators.optionalCnpj('11.222.333/0001-81'), isNull);
      expect(Validators.optionalCnpj('11.222.333/0001-00'), 'CNPJ inválido');
    });

    test('máscara formata enquanto digita', () {
      final r = CnpjInputFormatter().formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '11222333000181'),
      );
      expect(r.text, '11.222.333/0001-81');
    });
  });

  group('Quantidades, preço e códigos', () {
    test('inteiro respeita o mínimo', () {
      expect(Validators.integer('', min: 1), isNotNull);
      expect(Validators.integer('abc'), 'Digite apenas números');
      expect(Validators.integer('0', min: 1), isNotNull);
      expect(Validators.integer('3', min: 1), isNull);
    });

    test('preço precisa ser maior que zero', () {
      expect(Validators.price(r'R$ 0,00'), isNotNull);
      expect(Validators.price(r'R$ 5,49'), isNull);
      expect(Formatters.parseCurrency(r'R$ 1.234,56'), 1234.56);
    });

    test('código de barras opcional com 8 a 14 dígitos', () {
      expect(Validators.optionalBarcode(''), isNull);
      expect(Validators.optionalBarcode('123'), isNotNull);
      expect(Validators.optionalBarcode('7891000100103'), isNull);
    });

    test('código da empresa tem 6 caracteres', () {
      expect(Validators.companyCode('ABC12'), isNotNull);
      expect(Validators.companyCode('abc123'), isNull);
    });
  });
}
