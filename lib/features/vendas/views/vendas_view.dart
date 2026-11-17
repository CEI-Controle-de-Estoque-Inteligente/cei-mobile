import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/venda.dart';
import '../../../data/repositories/venda_repository.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/vendas_viewmodel.dart';

class VendasView extends StatelessWidget {
  const VendasView({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      key: ValueKey(perfil.id),
      create: (context) => VendasViewModel(context.read<VendaRepository>(), perfil)..recarregar(),
      child: const _VendasBody(),
    );
  }
}

class _VendasBody extends StatelessWidget {
  const _VendasBody();

  Future<void> _novaVenda(BuildContext context) async {
    final vm = context.read<VendasViewModel>();
    final registrou = await context.push<bool>(AppRoutes.vendaNova);
    if (registrou ?? false) vm.vendaRegistrada();
  }

  Future<void> _escolherPeriodo(BuildContext context, VendasViewModel vm) async {
    final hoje = DateTime.now();
    final faixa = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoje.year - 2),
      lastDate: hoje,
      initialDateRange: DateTimeRange(
        start: vm.intervalo.inicio,
        end: vm.intervalo.fim.subtract(const Duration(days: 1)),
      ),
      helpText: 'Período das vendas',
    );
    if (faixa == null) return;
    final inicio = DateTime(faixa.start.year, faixa.start.month, faixa.start.day);
    final fim = DateTime(faixa.end.year, faixa.end.month, faixa.end.day).add(const Duration(days: 1));
    vm.alterarPeriodo(PeriodoVendas.personalizado, personalizado: IntervaloDatas(inicio, fim));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendasViewModel>();
    final cores = Theme.of(context).extension<StockStatusColors>()!;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CeiButton(label: 'Registrar nova venda', icon: Icons.add_shopping_cart, onPressed: () => _novaVenda(context)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final p in PeriodoVendas.values)
              ChoiceChip(
                label: Text(
                  p == PeriodoVendas.personalizado && vm.periodo == p
                      ? '${Formatters.date(vm.intervalo.inicio)} - '
                            '${Formatters.date(vm.intervalo.fim.subtract(const Duration(days: 1)))}'
                      : p.label,
                ),
                selected: vm.periodo == p,
                onSelected: (_) => p == PeriodoVendas.personalizado
                    ? _escolherPeriodo(context, vm)
                    : vm.alterarPeriodo(p),
              ),
          ],
        ),
        if (vm.veTodas)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar só as minhas vendas'),
            value: vm.somenteMinhas,
            onChanged: vm.alternarSomenteMinhas,
          ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final largura = constraints.maxWidth >= 520 ? (constraints.maxWidth - 16) / 3 : constraints.maxWidth;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                SizedBox(
                  width: largura,
                  child: KpiCard(
                    icon: Icons.payments_outlined,
                    label: vm.veTodas && !vm.somenteMinhas ? 'Total da loja' : 'Total vendido',
                    value: Formatters.currency(vm.resumo.total),
                    detailColor: cores.ok,
                  ),
                ),
                SizedBox(
                  width: largura >= constraints.maxWidth ? (constraints.maxWidth - 8) / 2 : largura,
                  child: KpiCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transações',
                    value: '${vm.resumo.transacoes}',
                  ),
                ),
                SizedBox(
                  width: largura >= constraints.maxWidth ? (constraints.maxWidth - 8) / 2 : largura,
                  child: KpiCard(
                    icon: Icons.trending_up,
                    label: 'Ticket médio',
                    value: Formatters.currency(vm.resumo.ticketMedio),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Histórico detalhado', style: Theme.of(context).textTheme.titleMedium),
      ],
    );

    final Widget body;
    if (vm.carregando) {
      body = const LoadingView();
    } else if (vm.erro != null) {
      body = ErrorView(message: vm.erro!, onRetry: vm.recarregar);
    } else {
      body = PagedListView<Venda>(
        items: vm.itens,
        keyOf: (v) => v.id,
        hasMore: vm.temMais,
        isLoadingMore: vm.carregandoMais,
        onLoadMore: vm.carregarMais,
        onRefresh: vm.recarregar,
        header: vm.vazio
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 240, child: EmptyView(icon: Icons.receipt_long_outlined, title: 'Nenhuma venda no período')),
                ],
              )
            : header,
        itemBuilder: (context, venda) => _VendaTile(venda: venda, mostrarOperador: vm.veTodas),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(vm.veTodas ? 'Vendas da loja' : 'Minhas vendas')),
      body: body,
    );
  }
}

class _VendaTile extends StatelessWidget {
  const _VendaTile({required this.venda, required this.mostrarOperador});

  final Venda venda;
  final bool mostrarOperador;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detalhes = [
      '${venda.quantidade} x ${Formatters.currency(venda.precoUnitario)}',
      '${Formatters.date(venda.criadaEm)} às ${Formatters.time(venda.criadaEm)}',
      if (mostrarOperador && venda.operadorNome != null) venda.operadorNome!,
      if (venda.descontoPercentual > 0) 'promoção -${venda.descontoPercentual}%',
      if (venda.pendente) 'aguardando envio',
    ].join(' • ');

    return Card(
      child: ListTile(
        leading: const Icon(Icons.shopping_bag_outlined),
        title: Text(venda.produtoNome),
        subtitle: Text(detalhes),
        trailing: Text(
          Formatters.currency(venda.total),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
