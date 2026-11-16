import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/perfil.dart';
import '../../data/models/produto.dart';
import '../../features/assistente/views/assistente_view.dart';
import '../../features/auth/viewmodels/session_viewmodel.dart';
import '../../features/auth/views/cadastro_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/recuperar_senha_view.dart';
import '../../features/dashboard/views/dashboard_view.dart';
import '../../features/equipe/views/equipe_view.dart';
import '../../features/equipe/views/funcionario_form_view.dart';
import '../../features/estoque/views/alertas_view.dart';
import '../../features/estoque/views/movimentacao_view.dart';
import '../../features/estoque/views/produto_detalhe_view.dart';
import '../../features/estoque/views/produto_form_view.dart';
import '../../features/estoque/views/produtos_view.dart';
import '../../features/estoque/views/scanner_view.dart';
import '../../features/home/views/home_shell.dart';
import '../../features/home/views/sem_permissao_view.dart';
import '../../features/perfil/views/alterar_senha_view.dart';
import '../../features/perfil/views/perfil_view.dart';
import '../../features/settings/views/pendencias_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../features/splash/views/splash_view.dart';
import '../../features/vendas/views/nova_venda_view.dart';
import '../../features/vendas/views/vendas_view.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Roteador central com guards de autenticação e de perfil (C2.2 / C2.5).
GoRouter createAppRouter(SessionViewModel session) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) => _redirect(session, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashView()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginView()),
      GoRoute(path: AppRoutes.cadastro, builder: (_, _) => const CadastroView()),
      GoRoute(path: AppRoutes.recuperarSenha, builder: (_, _) => const RecuperarSenhaView()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.inicio, builder: (_, _) => const DashboardView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.estoque, builder: (_, _) => const ProdutosView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.vendas, builder: (_, _) => const VendasView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.equipe, builder: (_, _) => const EquipeView())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.perfil, builder: (_, _) => const PerfilView())],
          ),
        ],
      ),

      // Telas empilhadas sobre o shell (navegador raiz).
      GoRoute(path: AppRoutes.produtoNovo, builder: (_, _) => const ProdutoFormView()),
      GoRoute(path: AppRoutes.alertas, builder: (_, _) => const AlertasView()),
      GoRoute(
        path: '/estoque/produto/:id',
        builder: (_, state) => ProdutoDetalheView(
          produtoId: state.pathParameters['id']!,
          inicial: state.extra is Produto ? state.extra! as Produto : null,
        ),
        routes: [
          GoRoute(
            path: 'editar',
            redirect: (_, state) =>
                state.extra is Produto ? null : AppRoutes.produto(state.pathParameters['id']!),
            builder: (_, state) => ProdutoFormView(inicial: state.extra! as Produto),
          ),
          GoRoute(
            path: 'movimentar',
            redirect: (_, state) =>
                state.extra is Produto ? null : AppRoutes.produto(state.pathParameters['id']!),
            builder: (_, state) => MovimentacaoView(produto: state.extra! as Produto),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.scanner, builder: (_, _) => const ScannerView()),
      GoRoute(
        path: AppRoutes.vendaNova,
        builder: (_, state) =>
            NovaVendaView(produtoInicial: state.extra is Produto ? state.extra! as Produto : null),
      ),
      GoRoute(
        path: '/equipe/:id',
        redirect: (_, state) => state.extra is Perfil ? null : AppRoutes.equipe,
        builder: (_, state) => FuncionarioFormView(funcionario: state.extra! as Perfil),
      ),
      GoRoute(path: AppRoutes.assistente, builder: (_, _) => const AssistenteView()),
      GoRoute(path: AppRoutes.configuracoes, builder: (_, _) => const SettingsView()),
      GoRoute(path: AppRoutes.alterarSenha, builder: (_, _) => const AlterarSenhaView()),
      GoRoute(path: AppRoutes.pendencias, builder: (_, _) => const PendenciasView()),
      GoRoute(path: AppRoutes.semPermissao, builder: (_, _) => const SemPermissaoView()),
    ],
  );
}

String? _redirect(SessionViewModel session, String location) {
  final publica = AppRoutes.publicas.contains(location);

  switch (session.status) {
    case SessionStatus.carregando:
    case SessionStatus.erro:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionStatus.deslogado:
      if (location == AppRoutes.splash || !publica) return AppRoutes.login;
      return null;
    case SessionStatus.logado:
      if (session.recuperandoSenha) return null;
      if (publica) return AppRoutes.inicio;
      final modulo = AppRoutes.moduloDe(location);
      if (modulo != null && !session.pode(modulo)) return AppRoutes.semPermissao;
      return null;
  }
}
