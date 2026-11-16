import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Cliente HTTP compartilhado para APIs REST externas (C5.2 / C5.7):
/// timeouts, cabeçalhos padrão, log em debug e 1 nova tentativa em falha de rede.
Dio createHttpClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(RetryOnNetworkErrorInterceptor(dio));
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestHeader: false, responseHeader: false, logPrint: (o) => debugPrint('[http] $o')),
    );
  }
  return dio;
}

/// Repete a requisição uma única vez quando a falha é de conexão/timeout.
class RetryOnNetworkErrorInterceptor extends Interceptor {
  RetryOnNetworkErrorInterceptor(this._dio);

  final Dio _dio;
  static const String _retriedKey = 'cei_retried';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryable = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (!retryable || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final options = err.requestOptions..extra[_retriedKey] = true;
      final response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
