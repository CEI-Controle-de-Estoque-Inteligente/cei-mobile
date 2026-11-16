import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../data/models/perfil.dart';
import '../../../shared/widgets/connectivity_banner.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

class _Destino {
  const _Destino(this.branch, this.icon, this.selectedIcon, this.label, this.modulo);

  final int branch;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Modulo? modulo;
}

/// Estrutura das abas principais. Mostra apenas os módulos permitidos
/// para o cargo do usuário (RN001 - Tela inicial). Em telas largas usa
/// NavigationRail (layout adaptativo).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_Destino> _destinos = [
    _Destino(0, Icons.dashboard_outlined, Icons.dashboard, 'Início', Modulo.dashboard),
    _Destino(1, Icons.inventory_2_outlined, Icons.inventory_2, 'Estoque', Modulo.estoque),
    _Destino(2, Icons.point_of_sale_outlined, Icons.point_of_sale, 'Vendas', Modulo.vendas),
    _Destino(3, Icons.groups_outlined, Icons.groups, 'Equipe', Modulo.equipe),
    _Destino(4, Icons.person_outline, Icons.person, 'Perfil', null),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final visiveis = _destinos
        .where((d) => d.modulo == null || session.pode(d.modulo!))
        .toList();
    final selecionado = visiveis.indexWhere((d) => d.branch == navigationShell.currentIndex);
    final indice = selecionado < 0 ? 0 : selecionado;

    void irPara(int i) {
      final destino = visiveis[i];
      navigationShell.goBranch(
        destino.branch,
        initialLocation: destino.branch == navigationShell.currentIndex,
      );
    }

    final podeAssistente = session.pode(Modulo.assistente);
    final fab = podeAssistente
        ? FloatingActionButton(
            heroTag: 'assistente',
            tooltip: 'Assistente CEI',
            onPressed: () => context.push(AppRoutes.assistente),
            child: const Icon(Icons.smart_toy_outlined),
          )
        : null;

    final conteudo = Column(
      children: [
        Expanded(child: navigationShell),
        ConnectivityBanner(onTapPendentes: () => context.push(AppRoutes.pendencias)),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 840) {
          return Scaffold(
            floatingActionButton: fab,
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: indice,
                    onDestinationSelected: irPara,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in visiveis)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: conteudo),
              ],
            ),
          );
        }
        return Scaffold(
          floatingActionButton: fab,
          body: conteudo,
          bottomNavigationBar: NavigationBar(
            selectedIndex: indice,
            onDestinationSelected: irPara,
            destinations: [
              for (final d in visiveis)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                  tooltip: d.label,
                ),
            ],
          ),
        );
      },
    );
  }
}
