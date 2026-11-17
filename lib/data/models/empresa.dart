import 'tabela_descontos.dart';

class Empresa {
  const Empresa({
    required this.id,
    required this.nome,
    this.cnpj,
    this.codigoConvite,
    this.descontos = TabelaDescontos.padrao,
  });

  final String id;
  final String nome;
  final String? cnpj;

  /// Código que funcionários usam para se cadastrar na empresa.
  final String? codigoConvite;

  /// Tabela de descontos sugeridos, definida pelo gerente.
  final TabelaDescontos descontos;

  factory Empresa.fromJson(Map<String, dynamic> json) => Empresa(
    id: json['id'] as String,
    nome: (json['nome'] as String?) ?? '',
    cnpj: json['cnpj'] as String?,
    codigoConvite: json['codigo_convite'] as String?,
    descontos: TabelaDescontos.fromJson(json),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'cnpj': cnpj,
    'codigo_convite': codigoConvite,
    ...descontos.toJson(),
  };
}

/// Dados públicos de um CNPJ consultados na BrasilAPI (API REST externa).
class EmpresaCnpj {
  const EmpresaCnpj({required this.razaoSocial, this.nomeFantasia, this.municipio, this.uf});

  final String razaoSocial;
  final String? nomeFantasia;
  final String? municipio;
  final String? uf;

  String get nomeExibicao =>
      (nomeFantasia != null && nomeFantasia!.trim().isNotEmpty) ? nomeFantasia! : razaoSocial;

  factory EmpresaCnpj.fromJson(Map<String, dynamic> json) {
    final razao = json['razao_social'];
    if (razao is! String || razao.isEmpty) {
      throw const FormatException('razao_social ausente');
    }
    return EmpresaCnpj(
      razaoSocial: razao,
      nomeFantasia: json['nome_fantasia'] as String?,
      municipio: json['municipio'] as String?,
      uf: json['uf'] as String?,
    );
  }
}
