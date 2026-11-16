/// Produto encontrado pelo código de barras na API pública Open Food Facts.
class ProdutoExterno {
  const ProdutoExterno({required this.nome, this.marca, this.categoria});

  final String nome;
  final String? marca;
  final String? categoria;

  String get nomeCompleto =>
      (marca == null || marca!.isEmpty || nome.toLowerCase().contains(marca!.toLowerCase()))
      ? nome
      : '$nome - $marca';

  /// Retorna `null` quando a API responde "produto não encontrado".
  static ProdutoExterno? fromOpenFoodFacts(Map<String, dynamic> json) {
    if (json['status'] != 1) return null;
    final product = json['product'];
    if (product is! Map<String, dynamic>) {
      throw const FormatException('campo product ausente');
    }
    final nome = (product['product_name_pt'] as String?)?.trim().isNotEmpty == true
        ? product['product_name_pt'] as String
        : product['product_name'] as String?;
    if (nome == null || nome.trim().isEmpty) return null;

    final marcas = product['brands'] as String?;
    final categorias = product['categories'] as String?;
    return ProdutoExterno(
      nome: nome.trim(),
      marca: marcas?.split(',').first.trim(),
      categoria: categorias?.split(',').last.trim(),
    );
  }
}
