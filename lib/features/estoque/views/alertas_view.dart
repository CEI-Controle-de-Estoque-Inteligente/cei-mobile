import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/resultados.dart';
import '../../../shared/viewmodels/paginated_viewmodel.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../../shared/widgets/produto_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

/// Produtos que vencem em até 30 dias (alertas de 30, 15 e 5 dias).
class AlertasViewModel extends PaginatedViewModel<Produto> {
  AlertasViewModel(this._repository, this.empresaId);

  final ProdutoRepository _repository;
  final String empresaId;

  @override
  Future<Pagina<Produto>> buscarPagina(int pagina) =>
      _repository.listar(empresaId: empresaId, filtro: FiltroEstoque.vencendo, pagina: pagina);
}

class AlertasView extends StatelessWidget {
  const AlertasView({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      create: (context) => AlertasViewModel(context.read<ProdutoRepository>(), perfil.empresaId)..recarregar(),
      child: const _AlertasBody(),
    );
  }
}

class _AlertasBody extends StatelessWidget {
  const _AlertasBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AlertasViewModel>();

    final Widget body;
    if (vm.carregando) {
      body = const LoadingView();
    } else if (vm.erro != null) {
      body = ErrorView(message: vm.erro!, onRetry: vm.recarregar);
    } else if (vm.vazio) {
      body = RefreshIndicator(
        onRefresh: vm.recarregar,
        child: const EmptyView(
          icon: Icons.event_available_outlined,
          title: 'Nenhum produto vencendo',
          message: 'Nenhum item vence nos próximos 30 dias.',
        ),
      );
    } else {
      body = PagedListView<Produto>(
        items: vm.itens,
        keyOf: (p) => p.id,
        hasMore: vm.temMais,
        isLoadingMore: vm.carregandoMais,
        onLoadMore: vm.carregarMais,
        onRefresh: vm.recarregar,
        header: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Alertas são emitidos 30, 15 e 5 dias antes do vencimento. '
            'Itens com menos de 7 dias recebem sugestão automática de desconto.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        itemBuilder: (context, produto) => ProdutoCard(
          produto: produto,
          onTap: () => context.push(AppRoutes.produto(produto.id), extra: produto),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas de validade')),
      body: body,
    );
  }
}
