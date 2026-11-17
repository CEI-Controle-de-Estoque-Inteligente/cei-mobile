import '../../data/models/perfil.dart';

/// Caminhos centralizados das rotas (C2.2).
abstract final class AppRoutes {
  // Públicas
  static const String splash = '/';
  static const String login = '/login';
  static const String cadastro = '/cadastro';
  static const String recuperarSenha = '/recuperar-senha';

  // Abas (shell com navegação inferior)
  static const String inicio = '/inicio';
  static const String estoque = '/estoque';
  static const String vendas = '/vendas';
  static const String equipe = '/equipe';
  static const String perfil = '/perfil';

  // Telas empilhadas
  static const String produtoNovo = '/estoque/novo';
  static const String alertas = '/estoque/alertas';
  static const String scanner = '/scanner';
  static const String vendaNova = '/vendas/nova';
  static const String assistente = '/assistente';
  static const String configuracoes = '/configuracoes';
  static const String alterarSenha = '/perfil/senha';
  static const String pendencias = '/pendencias';
  static const String descontos = '/configuracoes/descontos';
  static const String semPermissao = '/sem-permissao';

  static String produto(String id) => '/estoque/produto/$id';
  static String produtoEditar(String id) => '/estoque/produto/$id/editar';
  static String produtoMovimentar(String id) => '/estoque/produto/$id/movimentar';
  static String funcionario(String id) => '/equipe/$id';

  static const Set<String> publicas = {splash, login, cadastro, recuperarSenha};

  /// Módulo exigido por cada caminho (null = livre para qualquer cargo logado).
  static Modulo? moduloDe(String location) {
    if (location == produtoNovo ||
        location.endsWith('/editar') ||
        location.endsWith('/movimentar')) {
      return Modulo.estoqueEditar;
    }
    if (location.startsWith(estoque) || location == scanner) return Modulo.estoque;
    if (location.startsWith(vendas)) return Modulo.vendas;
    if (location.startsWith(equipe)) return Modulo.equipe;
    if (location == assistente) return Modulo.assistente;
    if (location == descontos) return Modulo.promocoes;
    return null;
  }
}
