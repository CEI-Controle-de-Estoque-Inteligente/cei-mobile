import 'empresa.dart';

/// Módulos/ações do app usados no controle de acesso por perfil (RBAC).
enum Modulo {
  dashboard,
  estoque,
  estoqueEditar,
  estoqueExcluir,
  vendas,
  vendasTodas,
  equipe,
  assistente,
}

enum Cargo {
  gerente('Gerente'),
  vendedor('Vendedor'),
  caixa('Caixa'),
  estoquista('Estoquista');

  const Cargo(this.label);

  final String label;

  static Cargo fromName(String? value) => Cargo.values.firstWhere(
    (c) => c.name == value,
    orElse: () => Cargo.vendedor,
  );

  static final Map<Cargo, Set<Modulo>> _permissoes = {
    Cargo.gerente: {...Modulo.values},
    Cargo.vendedor: {Modulo.dashboard, Modulo.estoque, Modulo.vendas, Modulo.assistente},
    Cargo.caixa: {Modulo.dashboard, Modulo.estoque, Modulo.vendas, Modulo.assistente},
    Cargo.estoquista: {
      Modulo.dashboard,
      Modulo.estoque,
      Modulo.estoqueEditar,
      Modulo.assistente,
    },
  };

  /// Espelha as regras aplicadas no banco (RLS + RPCs). A interface usa isto
  /// para esconder o que o usuário não pode fazer; o backend garante de fato.
  bool permite(Modulo modulo) => _permissoes[this]!.contains(modulo);
}

enum Turno {
  manha('Manhã'),
  tarde('Tarde'),
  integral('Integral');

  const Turno(this.label);

  final String label;

  static Turno fromName(String? value) => Turno.values.firstWhere(
    (t) => t.name == value,
    orElse: () => Turno.integral,
  );
}

enum StatusFuncionario {
  ativo('Ativo'),
  ferias('Férias'),
  afastado('Afastado');

  const StatusFuncionario(this.label);

  final String label;

  static StatusFuncionario fromName(String? value) =>
      StatusFuncionario.values.firstWhere(
        (s) => s.name == value,
        orElse: () => StatusFuncionario.ativo,
      );
}

/// Perfil do usuário/funcionário (tabela `perfis`).
class Perfil {
  const Perfil({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.email,
    required this.cargo,
    required this.turno,
    required this.status,
    required this.ativo,
    this.empresa,
  });

  final String id;
  final String empresaId;
  final String nome;
  final String email;
  final Cargo cargo;
  final Turno turno;
  final StatusFuncionario status;
  final bool ativo;
  final Empresa? empresa;

  bool pode(Modulo modulo) => cargo.permite(modulo);

  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  factory Perfil.fromJson(Map<String, dynamic> json) {
    final empresaJson = json['empresas'];
    return Perfil(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      nome: (json['nome'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      cargo: Cargo.fromName(json['cargo'] as String?),
      turno: Turno.fromName(json['turno'] as String?),
      status: StatusFuncionario.fromName(json['status'] as String?),
      ativo: (json['ativo'] as bool?) ?? true,
      empresa: empresaJson is Map<String, dynamic> ? Empresa.fromJson(empresaJson) : null,
    );
  }

  /// Formato completo usado no cache local do perfil (modo offline).
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'empresa_id': empresaId,
    'nome': nome,
    'email': email,
    'cargo': cargo.name,
    'turno': turno.name,
    'status': status.name,
    'ativo': ativo,
    if (empresa != null) 'empresas': empresa!.toJson(),
  };

  /// Campos editáveis pelo gerente na gestão de equipe.
  Map<String, dynamic> toUpdateJson() => {
    'cargo': cargo.name,
    'turno': turno.name,
    'status': status.name,
    'ativo': ativo,
  };

  Perfil copyWith({
    String? nome,
    Cargo? cargo,
    Turno? turno,
    StatusFuncionario? status,
    bool? ativo,
  }) {
    return Perfil(
      id: id,
      empresaId: empresaId,
      nome: nome ?? this.nome,
      email: email,
      cargo: cargo ?? this.cargo,
      turno: turno ?? this.turno,
      status: status ?? this.status,
      ativo: ativo ?? this.ativo,
      empresa: empresa,
    );
  }
}
