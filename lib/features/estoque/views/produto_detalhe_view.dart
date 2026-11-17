import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/movimentacao.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/stock_level_bar.dart';
import '../../../shared/widgets/validade_chip.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/produto_detalhe_viewmodel.dart';
import 'produtos_view.dart';
import 'promocao_card.dart';

class ProdutoDetalheView extends StatelessWidget {
  const ProdutoDetalheView({super.key, required this.produtoId, this.inicial});

  final String produtoId;

  /// Objeto tipado recebido pela navegação (C2.3); se ausente, é carregado.
  final Produto? inicial;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProdutoRepository>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProdutoDetalheViewModel(repo, produtoId, inicial: inicial)..carregar(),
        ),
        ChangeNotifierProvider(create: (_) => HistoricoViewModel(repo, produtoId)..recarregar()),
      ],
      child: const _DetalheBody(),
    );
  }
}

class _DetalheBody extends StatelessWidget {
  const _DetalheBody();

  Future<void> _movimentar(BuildContext context, Produto produto) async {
    final vm = context.read<ProdutoDetalheViewModel>();
    final historico = context.read<HistoricoViewModel>();
    final atualizado = await context.push<Produto>(AppRoutes.produtoMovimentar(produto.id), extra: produto);
    if (atualizado != null) {
      vm.atualizar(atualizado);
      await historico.recarregar();
    }
  }

  Future<void> _editar(BuildContext context, Produto produto) async {
    final vm = context.read<ProdutoDetalheViewModel>();
    final atualizado = await context.push<Produto>(AppRoutes.produtoEditar(produto.id), extra: produto);
    if (atualizado != null) vm.atualizar(atualizado);
  }

  Future<void> _aplicarPromocao(BuildContext context, int percentual) async {
    final vm = context.read<ProdutoDetalheViewModel>();
    try {
      await vm.aplicarPromocao(percentual);
      if (!context.mounted) return;
      AppFeedback.success(
        context,
        percentual == 0 ? 'Promoção encerrada.' : 'Promoção de $percentual% aplicada. As vendas já usam o novo preço.',
      );
    } on AppException catch (e) {
      if (context.mounted) AppFeedback.error(context, e.message);
    }
  }

  Future<void> _excluir(BuildContext context, Produto produto) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Excluir produto?',
      message: '"${produto.nome}" sairá do estoque. O histórico de vendas é mantido.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final vm = context.read<ProdutoDetalheViewModel>();
    final repo = context.read<ProdutoRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await vm.excluir();
      if (!context.mounted) return;
      Navigator.of(context).pop(ProdutoExcluido.sinal);
      messenger.showSnackBar(
        SnackBar(
          content: Text('"${produto.nome}" excluído.'),
          action: SnackBarAction(label: 'Desfazer', onPressed: () => repo.restaurar(produto)),
        ),
      );
    } on AppException catch (e) {
      if (context.mounted) AppFeedback.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProdutoDetalheViewModel>();
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    final produto = vm.produto;

    return PopScope<Object?>(
      canPop: false,
      // Devolve o produto atualizado para a listagem (retorno de resultado).
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(result ?? vm.produto);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(produto?.nome ?? 'Produto', overflow: TextOverflow.ellipsis),
          actions: [
            if (produto != null && (perfil?.pode(Modulo.estoqueEditar) ?? false))
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editar(context, produto),
              ),
            if (produto != null && (perfil?.pode(Modulo.estoqueExcluir) ?? false))
              IconButton(
                tooltip: 'Excluir',
                icon: const Icon(Icons.delete_outline),
                onPressed: vm.excluindo ? null : () => _excluir(context, produto),
              ),
          ],
        ),
        body: _corpo(context, vm, perfil),
      ),
    );
  }

  Widget _corpo(BuildContext context, ProdutoDetalheViewModel vm, Perfil? perfil) {
    if (vm.carregando) return const LoadingView();
    if (vm.erro != null) return ErrorView(message: vm.erro!, onRetry: vm.carregar);
    final produto = vm.produto!;
    final historico = context.watch<HistoricoViewModel>();
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        await vm.carregar();
        await historico.recarregar();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${produto.quantidade} unidades',
                              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          StatusBadge.estoque(context, produto.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StockLevelBar(produto: produto, height: 12),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Mínimo ${produto.estoqueMinimo}'
                        '${produto.estoqueMaximo > 0 ? ' • Capacidade ${produto.estoqueMaximo}' : ''}',
                        style: textTheme.bodySmall,
                      ),
                      const Divider(height: AppSpacing.lg),
                      _Info(label: 'Preço unitário', valor: Formatters.currency(produto.preco)),
                      if (produto.emPromocao)
                        _Info(
                          label: 'Preço promocional (-${produto.promocaoPercentual}%)',
                          valor: Formatters.currency(produto.precoVenda),
                        ),
                      _Info(label: 'Valor em estoque', valor: Formatters.currency(produto.valorEmEstoque)),
                      if (produto.categoria != null) _Info(label: 'Categoria', valor: produto.categoria!),
                      if (produto.codigoBarras != null) _Info(label: 'Código de barras', valor: produto.codigoBarras!),
                      _Info(
                        label: 'Validade',
                        valor: produto.validade == null ? 'Não controla' : Formatters.date(produto.validade!),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ValidadeChip(produto: produto),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  if (perfil?.pode(Modulo.promocoes) ?? false) ...[
                    PromocaoCard(
                      produto: produto,
                      salvando: vm.salvandoPromocao,
                      onAplicar: (percentual) => _aplicarPromocao(context, percentual),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (perfil?.pode(Modulo.estoqueEditar) ?? false)
                    CeiButton(
                      label: 'Registrar entrada / saída',
                      icon: Icons.swap_vert,
                      onPressed: () => _movimentar(context, produto),
                    ),
                  if (perfil?.pode(Modulo.vendas) ?? false) ...[
                    const SizedBox(height: AppSpacing.sm),
                    CeiButton(
                      label: 'Vender este produto',
                      icon: Icons.add_shopping_cart,
                      variant: CeiButtonVariant.secondary,
                      onPressed: produto.quantidade == 0
                          ? null
                          : () => context.push(AppRoutes.vendaNova, extra: produto),
                    ),
                  ],
                  const SectionHeader(title: 'Histórico de movimentações'),
                ],
              ),
            ),
          ),
          ..._historico(context, historico),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  List<Widget> _historico(BuildContext context, HistoricoViewModel historico) {
    if (historico.carregando) {
      return const [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: LoadingView()))];
    }
    if (historico.erro != null) {
      return [
        SliverToBoxAdapter(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(historico.erro!),
            trailing: TextButton(onPressed: historico.recarregar, child: const Text('Tentar novamente')),
          ),
        ),
      ];
    }
    if (historico.vazio) {
      return const [SliverToBoxAdapter(child: ListTile(title: Text('Nenhuma movimentação ainda.')))];
    }
    final itens = historico.itens;
    return [
      SliverList.builder(
        itemCount: itens.length + (historico.temMais ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == itens.length) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: historico.carregandoMais
                  ? const Center(child: CircularProgressIndicator())
                  : CeiButton(
                      label: 'Carregar mais',
                      variant: CeiButtonVariant.text,
                      onPressed: historico.carregarMais,
                    ),
            );
          }
          return _MovimentacaoTile(key: ValueKey(itens[i].id), movimentacao: itens[i]);
        },
      ),
    ];
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimentacaoTile extends StatelessWidget {
  const _MovimentacaoTile({super.key, required this.movimentacao});

  final Movimentacao movimentacao;

  @override
  Widget build(BuildContext context) {
    final m = movimentacao;
    final icon = switch (m.tipo) {
      TipoMovimentacao.entrada => Icons.south_west,
      TipoMovimentacao.saida => Icons.north_east,
      TipoMovimentacao.venda => Icons.shopping_bag_outlined,
      TipoMovimentacao.ajuste => Icons.tune,
    };
    final detalhes = [
      Formatters.dateTime(m.criadaEm),
      if (m.usuarioNome != null) m.usuarioNome!,
      if (m.observacao != null) m.observacao!,
    ].join(' • ');
    return ListTile(
      leading: Icon(icon),
      title: Text(m.tipo.label),
      subtitle: Text(detalhes),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(m.quantidadeFormatada, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('saldo ${m.saldoApos}', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
