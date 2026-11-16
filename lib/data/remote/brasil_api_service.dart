import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../models/empresa.dart';

/// API REST pública BrasilAPI: preenche o nome da empresa pelo CNPJ (C5.2).
class BrasilApiService {
  BrasilApiService(this._dio);

  final Dio _dio;

  Future<EmpresaCnpj> consultarCnpj(String cnpjDigits) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://brasilapi.com.br/api/cnpj/v1/$cnpjDigits',
      );
      final data = response.data;
      if (data == null) throw const FormatException('resposta vazia');
      return EmpresaCnpj.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 400) {
        throw const AppException('CNPJ não encontrado na Receita Federal.');
      }
      throw ErrorMapper.map(e);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
