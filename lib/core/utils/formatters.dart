import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formatação de valores para exibição (pt-BR).
abstract final class Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
  );
  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final DateFormat _time = DateFormat('HH:mm', 'pt_BR');

  static String currency(num value) => _currency.format(value);
  static String date(DateTime value) => _date.format(value.toLocal());
  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());
  static String time(DateTime value) => _time.format(value.toLocal());

  static String percent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  /// "R$ 1.234,56" -> 1234.56
  static double parseCurrency(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 0;
    return int.parse(digits) / 100;
  }

  static String onlyDigits(String text) => text.replaceAll(RegExp(r'\D'), '');

  static String cnpj(String digits) {
    final d = onlyDigits(digits);
    if (d.length != 14) return digits;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
        '${d.substring(8, 12)}-${d.substring(12)}';
  }
}

/// Máscara de moeda: o usuário digita apenas números (C2.8).
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = Formatters.onlyDigits(newValue.text);
    if (digits.isEmpty) return const TextEditingValue();
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final text = Formatters.currency(int.parse(limited) / 100);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Máscara de CNPJ: 00.000.000/0000-00.
class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = Formatters.onlyDigits(newValue.text);
    if (digits.length > 14) digits = digits.substring(0, 14);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
