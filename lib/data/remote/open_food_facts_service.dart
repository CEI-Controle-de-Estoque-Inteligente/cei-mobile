import 'package:dio/dio.dart';

import '../../core/errors/error_mapper.dart';
import '../models/produto_externo.dart';

/// API REST pública Open Food Facts: sugere nome/categoria a partir do
/// código de barras no cadastro de produtos (C5.2).
class OpenFoodFactsService {
  OpenFoodFactsService(this._dio);

  final Dio _dio;
  static const String _base = 'https://world.openfoodfacts.org/api/v2/product';

  /// Retorna `null` quando o código não existe na base.
  Future<ProdutoExterno?> buscarPorCodigo(String codigo) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_base/$codigo.json',
        queryParameters: {'fields': 'product_name,product_name_pt,brands,categories'},
      );
      final data = response.data;
      if (data == null) throw const FormatException('resposta vazia');
      return ProdutoExterno.fromOpenFoodFacts(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ErrorMapper.map(e);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
