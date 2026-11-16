import 'formatters.dart';

/// Validadores reutilizáveis de formulário (C2.8).
abstract final class Validators {
  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? notEmpty(String? value, {String message = 'Campo obrigatório'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? value) {
    final empty = notEmpty(value, message: 'Informe o e-mail');
    if (empty != null) return empty;
    if (!_emailRegex.hasMatch(value!.trim())) {
      return 'Informe um e-mail válido';
    }
    return null;
  }

  static String? password(String? value, {int minLength = 8}) {
    final empty = notEmpty(value, message: 'Informe a senha');
    if (empty != null) return empty;
    if (value!.length < minLength) {
      return 'A senha deve ter pelo menos $minLength caracteres';
    }
    return null;
  }

  /// Senha forte para cadastro: 8+ caracteres, com letra e número.
  static String? strongPassword(String? value) {
    final basic = password(value);
    if (basic != null) return basic;
    final hasLetter = RegExp('[A-Za-z]').hasMatch(value!);
    final hasNumber = RegExp('[0-9]').hasMatch(value);
    if (!hasLetter || !hasNumber) {
      return 'Use letras e números na senha';
    }
    return null;
  }

  static String? Function(String?) confirmPassword(String Function() original) {
    return (value) {
      final empty = notEmpty(value, message: 'Confirme a senha');
      if (empty != null) return empty;
      if (value != original()) return 'As senhas não coincidem';
      return null;
    };
  }

  static String? name(String? value) {
    final empty = notEmpty(value, message: 'Informe o nome');
    if (empty != null) return empty;
    if (value!.trim().length < 2) return 'O nome deve ter pelo menos 2 letras';
    if (value.trim().length > 120) return 'O nome deve ter no máximo 120 caracteres';
    return null;
  }

  /// CNPJ opcional: se informado, precisa ser válido (dígitos verificadores).
  static String? optionalCnpj(String? value) {
    final digits = Formatters.onlyDigits(value ?? '');
    if (digits.isEmpty) return null;
    if (!isValidCnpj(digits)) return 'CNPJ inválido';
    return null;
  }

  static bool isValidCnpj(String digits) {
    if (digits.length != 14 || RegExp(r'^(\d)\1+$').hasMatch(digits)) {
      return false;
    }
    int calc(int length) {
      final weights = length == 12
          ? [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
          : [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      var sum = 0;
      for (var i = 0; i < length; i++) {
        sum += int.parse(digits[i]) * weights[i];
      }
      final rest = sum % 11;
      return rest < 2 ? 0 : 11 - rest;
    }

    return calc(12) == int.parse(digits[12]) && calc(13) == int.parse(digits[13]);
  }

  static String? companyCode(String? value) {
    final empty = notEmpty(value, message: 'Informe o código da empresa');
    if (empty != null) return empty;
    if (!RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(value!.trim())) {
      return 'O código tem 6 letras/números';
    }
    return null;
  }

  static String? otpCode(String? value) {
    final empty = notEmpty(value, message: 'Informe o código recebido');
    if (empty != null) return empty;
    if (!RegExp(r'^\d{6,8}$').hasMatch(value!.trim())) {
      return 'O código tem de 6 a 8 números';
    }
    return null;
  }

  /// Inteiro >= [min].
  static String? integer(String? value, {int min = 0, String field = 'Quantidade'}) {
    final empty = notEmpty(value, message: 'Campo obrigatório');
    if (empty != null) return empty;
    final parsed = int.tryParse(value!.trim());
    if (parsed == null) return 'Digite apenas números';
    if (parsed < min) return '$field deve ser no mínimo $min';
    if (parsed > 1000000) return '$field muito alta';
    return null;
  }

  static String? price(String? value) {
    final empty = notEmpty(value, message: 'Informe o preço');
    if (empty != null) return empty;
    if (Formatters.parseCurrency(value!) <= 0) return 'O preço deve ser maior que zero';
    return null;
  }

  static String? optionalBarcode(String? value) {
    final digits = (value ?? '').trim();
    if (digits.isEmpty) return null;
    if (!RegExp(r'^\d{8,14}$').hasMatch(digits)) {
      return 'Código de barras deve ter de 8 a 14 números';
    }
    return null;
  }
}
