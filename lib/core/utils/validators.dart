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
}
