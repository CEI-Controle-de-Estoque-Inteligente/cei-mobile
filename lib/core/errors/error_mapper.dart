import 'dart:async';

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app_exception.dart';

/// Converte qualquer erro técnico (Supabase, Dio, rede, JSON) em uma
/// [AppException] com mensagem amigável (C5.4). Usado pelos repositórios,
/// para que a UI nunca receba exceções cruas.
abstract final class ErrorMapper {
  static AppException map(Object error) {
    if (error is AppException) return error;
    if (error is TimeoutException) return const TimeoutAppException();
    if (error is FormatException) return const DataFormatException();
    if (error is sb.AuthException) return _auth(error);
    if (error is sb.PostgrestException) return _postgrest(error);
    if (error is DioException) return _dio(error);
    if (_looksLikeNetwork(error)) return const NetworkException();
    return const AppException('Algo deu errado. Tente novamente.');
  }

  /// Indica se o erro foi causado por falta de conexão (usado pela fila offline).
  static bool isNetwork(Object error) {
    final mapped = map(error);
    return mapped is NetworkException || mapped is TimeoutAppException;
  }

  static bool _looksLikeNetwork(Object error) {
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection refused') ||
        text.contains('Network is unreachable') ||
        text.contains('XMLHttpRequest') ||
        text.contains('Failed to fetch');
  }

  static AppException _auth(sb.AuthException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();

    if (e.statusCode == null && _looksLikeNetwork(e.message)) {
      return const NetworkException();
    }
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const AuthAppException('E-mail ou senha incorretos.');
    }
    if (code == 'email_not_confirmed') {
      return const AuthAppException(
        'Confirme seu e-mail antes de entrar. Verifique sua caixa de entrada.',
      );
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return const AuthAppException('Este e-mail já está cadastrado.');
    }
    if (code == 'weak_password') {
      return const AuthAppException(
        'Senha fraca. Use pelo menos 8 caracteres, com letras e números.',
      );
    }
    if (code == 'same_password') {
      return const AuthAppException('A nova senha deve ser diferente da atual.');
    }
    if (code == 'otp_expired' || message.contains('token has expired')) {
      return const AuthAppException(
        'Código inválido ou expirado. Solicite um novo código.',
      );
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        e.statusCode == '429') {
      return const AuthAppException(
        'Muitas tentativas em pouco tempo. Aguarde alguns minutos.',
      );
    }
    if (message.contains('database error saving new user')) {
      return const AuthAppException(
        'Não foi possível criar a conta. Confira o código da empresa.',
      );
    }
    if (code == 'session_not_found' || code == 'refresh_token_not_found') {
      return const AuthAppException('Sua sessão expirou. Entre novamente.');
    }
    return const AuthAppException(
      'Não foi possível concluir a autenticação. Tente novamente.',
    );
  }

  static AppException _postgrest(sb.PostgrestException e) {
    switch (e.code) {
      case 'P0001':
        // Mensagens das nossas funções SQL já são amigáveis.
        return AppException(e.message);
      case '42501':
        return e.message.contains('row-level security')
            ? const PermissionException()
            : PermissionException(e.message);
      case '23505':
        return const AppException(
          'Já existe um registro com estes dados (ex.: código de barras repetido).',
        );
      case '23514':
      case '22P02':
        return const AppException('Alguns dados informados são inválidos.');
      case 'PGRST116':
        return const AppException('Registro não encontrado.');
      case 'PGRST301':
      case 'PGRST303':
        return const AuthAppException('Sua sessão expirou. Entre novamente.');
    }
    if (_looksLikeNetwork(e.message)) return const NetworkException();
    return const AppException('Não foi possível concluir a operação. Tente novamente.');
  }

  static AppException _dio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutAppException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 404) {
          return const AppException('Nenhum resultado encontrado.');
        }
        if (status == 429) {
          return const AppException('Muitas consultas seguidas. Aguarde um instante.');
        }
        if (status >= 500) {
          return const AppException('O serviço externo está indisponível no momento.');
        }
        return const AppException('A consulta não pôde ser concluída.');
      case DioExceptionType.cancel:
        return const AppException('Operação cancelada.');
      default:
        if (e.error is FormatException) return const DataFormatException();
        return const NetworkException();
    }
  }
}
