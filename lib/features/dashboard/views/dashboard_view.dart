import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/equipe_repository.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/produto_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      key: ValueKey(perfil.id),
      create: (context) => DashboardViewModel(
        dashboard: context.read<DashboardRepository>(),
        produtos: context.read<ProdutoRepository>(),
        perfil: perfil,
      )..carregar(),
      child: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DashboardViewModel>();
    final perfil = vm.perfil;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: Row(
          children: [
            UserAvatar(iniciais: perfil.iniciais, nome: perfil.nome, radius: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá, ${perfil.nome.split(' ').first}', overflow: TextOverflow.ellipsis),
                  Text(
                    '${perfil.cargo.label} • ${perfil.empresa?.nome ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.configuracoes),
          ),
        ],
      ),
      body: _conteudo(context, vm),
    );
  }

  Widget _conteudo(BuildContext context, DashboardViewModel vm) {
    if (vm.carregando) return const LoadingView(message: 'Carregando indicadores...');
    if (vm.erro != null) return ErrorView(message: vm.erro!, onRetry: vm.carregar);

    final perfil = vm.perfil;
    final resumo = vm.resumo;
    final cores = Theme.of(context).extension<StockStatusColors>()!;
    final variacao = resumo?.variacaoFaturamento;

    final kpis = <Widget>[
      if (perfil.pode(Modulo.vendas) && resumo != null)
        KpiCard(
          icon: Icons.payments_outlined,
          label: perfil.pode(Modulo.vendasTodas) ? 'Faturamento hoje' : 'Minhas vendas hoje',
          value: Formatters.currency(resumo.faturamentoHoje),
          detail: variacao == null ? 'Sem vendas ontem para comparar' : '${Formatters.percent(variacao)} vs ontem',
          detailColor: variacao == null ? null : (variacao >= 0 ? cores.ok : cores.critical),
          onTap: () => context.go(AppRoutes.vendas),
        ),
      if (resumo != null)
        KpiCard(
          icon: Icons.inventory_2_outlined,
          label: 'Itens em estoque',
          value: '${resumo.itensEstoque}',
          detail: '${resumo.itensCriticos} produto(s) abaixo do mínimo',
          detailColor: resumo.itensCriticos > 0 ? cores.critical : cores.ok,
          onTap: () => context.go(AppRoutes.estoque),
        ),
      if (resumo != null)
        KpiCard(
          icon: Icons.event_busy_outlined,
          label: 'Vencendo em 15 dias',
          value: '${resumo.vencendo15}',
          detail: resumo.vencidos > 0 ? '${resumo.vencidos} vencido(s) com estoque' : 'Nenhum vencido',
          detailColor: resumo.vencidos > 0 ? cores.critical : null,
          onTap: () => context.push(AppRoutes.alertas),
        ),
      if (perfil.pode(Modulo.vendas) && resumo != null)
        KpiCard(
          icon: Icons.receipt_long_outlined,
          label: 'Vendas hoje',
          value: '${resumo.vendasHoje}',
          detail: resumo.vendasHoje == 0
              ? null
              : 'Ticket médio ${Formatters.currency(resumo.faturamentoHoje / resumo.vendasHoje)}',
        ),
    ];

    return RefreshIndicator(
      onRefresh: vm.carregar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            sliver: SliverToBoxAdapter(child: _Atalhos(perfil: perfil)),
          ),
          if (vm.avisoResumo != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(vm.avisoResumo!),
                  ),
                ),
              ),
            ),
          if (kpis.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverGrid.builder(
                // Altura acompanha a escala de fonte do sistema (C1.4).
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 150 * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.2).toDouble(),
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                itemCount: kpis.length,
                itemBuilder: (context, i) => kpis[i],
              ),
            ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Recomendações inteligentes')),
          ),
          if (vm.recomendacoes.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.verified_outlined),
                    title: Text('Tudo em ordem por aqui!'),
                    subtitle: Text('Sem itens críticos ou próximos do vencimento.'),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: vm.recomendacoes.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) => _RecomendacaoTile(recomendacao: vm.recomendacoes[i]),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Alertas de validade',
                actionLabel: 'Ver todos',
                onAction: () => context.push(AppRoutes.alertas),
              ),
            ),
          ),
          if (vm.vencendo.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.event_available_outlined),
                    title: Text('Nenhum produto vence nos próximos 15 dias'),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
              sliver: SliverList.separated(
                itemCount: vm.vencendo.length > 5 ? 5 : vm.vencendo.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final p = vm.vencendo[i];
                  return ProdutoCard(
                    key: ValueKey(p.id),
                    produto: p,
                    onTap: () => context.push(AppRoutes.produto(p.id), extra: p),
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

class _Atalhos extends StatelessWidget {
  const _Atalhos({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (perfil.pode(Modulo.vendas))
          ActionChip(
            avatar: const Icon(Icons.add_shopping_cart),
            label: const Text('Nova venda'),
            onPressed: () => context.push(AppRoutes.vendaNova),
          ),
        if (perfil.pode(Modulo.estoqueEditar))
          ActionChip(
            avatar: const Icon(Icons.add_box_outlined),
            label: const Text('Novo produto'),
            onPressed: () => context.push(AppRoutes.produtoNovo),
          ),
        ActionChip(
          avatar: const Icon(Icons.inventory_2_outlined),
          label: const Text('Estoque'),
          onPressed: () => context.go(AppRoutes.estoque),
        ),
        ActionChip(
          avatar: const Icon(Icons.notifications_active_outlined),
          label: const Text('Alertas'),
          onPressed: () => context.push(AppRoutes.alertas),
        ),
      ],
    );
  }
}

class _RecomendacaoTile extends StatelessWidget {
  const _RecomendacaoTile({required this.recomendacao});

  final Recomendacao recomendacao;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).extension<StockStatusColors>()!;
    final (icon, color) = switch (recomendacao.tipo) {
      TipoRecomendacao.desconto => (Icons.sell_outlined, cores.low),
      TipoRecomendacao.repor => (Icons.add_shopping_cart, cores.critical),
      TipoRecomendacao.aumentarPedido => (Icons.trending_up, cores.ok),
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(recomendacao.titulo),
        subtitle: Text(recomendacao.detalhe),
        trailing: recomendacao.produtoId == null ? null : const Icon(Icons.chevron_right),
        onTap: recomendacao.produtoId == null
            ? null
            : () => context.push(AppRoutes.produto(recomendacao.produtoId!)),
      ),
    );
  }
}
