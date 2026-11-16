import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../../shared/widgets/produto_card.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/produtos_viewmodel.dart';

class ProdutosView extends StatelessWidget {
  const ProdutosView({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      key: ValueKey(perfil.id),
      create: (context) =>
          ProdutosViewModel(context.read<ProdutoRepository>(), perfil.empresaId)..recarregar(),
      child: _ProdutosBody(perfil: perfil),
    );
  }
}

class _ProdutosBody extends StatelessWidget {
  const _ProdutosBody({required this.perfil});

  final Perfil perfil;

  Future<void> _novoProduto(BuildContext context) async {
    final vm = context.read<ProdutosViewModel>();
    final criado = await context.push<Produto>(AppRoutes.produtoNovo);
    if (criado != null) await vm.recarregar();
  }

  Future<void> _abrir(BuildContext context, Produto produto) async {
    final vm = context.read<ProdutosViewModel>();
    // Retorno de resultado entre telas (C2.2): a tela de detalhe devolve o
    // produto atualizado, ou null se foi excluído.
    final resultado = await context.push<Object?>(AppRoutes.produto(produto.id), extra: produto);
    if (resultado is Produto) vm.produtoAtualizado(resultado);
    if (resultado == ProdutoExcluido.sinal) await vm.recarregar();
  }

  Future<void> _escanear(BuildContext context) async {
    final vm = context.read<ProdutosViewModel>();
    final repo = context.read<ProdutoRepository>();
    final codigo = await context.push<String>(AppRoutes.scanner);
    if (codigo == null || !context.mounted) return;
    try {
      final produto = await repo.buscarPorCodigo(vm.empresaId, codigo);
      if (!context.mounted) return;
      if (produto != null) {
        await _abrir(context, produto);
      } else {
        AppFeedback.info(context, 'Nenhum produto com o código $codigo.');
      }
    } on AppException catch (e) {
      if (context.mounted) AppFeedback.error(context, e.message);
    }
  }

  Future<bool> _confirmarExclusao(BuildContext context, Produto produto) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Excluir produto?',
      message: '"${produto.nome}" sairá da lista de estoque. Você poderá desfazer logo em seguida.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok || !context.mounted) return false;

    final vm = context.read<ProdutosViewModel>();
    try {
      final indice = await vm.excluir(produto);
      if (context.mounted) {
        AppFeedback.success(
          context,
          'Produto excluído.',
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => vm.desfazerExclusao(produto, indice),
          ),
        );
      }
    } on AppException catch (e) {
      if (context.mounted) AppFeedback.error(context, e.message);
    }
    // O item já foi removido pelo ViewModel; o Dismissible não precisa animar.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProdutosViewModel>();
    final podeEditar = perfil.pode(Modulo.estoqueEditar);
    final podeExcluir = perfil.pode(Modulo.estoqueExcluir);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estoque'),
        actions: [
          IconButton(
            tooltip: 'Alertas de validade',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => context.push(AppRoutes.alertas),
          ),
          IconButton(
            tooltip: 'Buscar por código de barras',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _escanear(context),
          ),
          if (podeEditar)
            IconButton(
              tooltip: 'Novo produto',
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () => _novoProduto(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: SearchField(
              hint: 'Buscar por nome ou código',
              initialValue: vm.busca,
              onChanged: vm.buscar,
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              children: [
                for (final filtro in FiltroEstoque.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(filtro.label),
                      selected: vm.filtro == filtro,
                      onSelected: (_) => vm.filtrar(filtro),
                    ),
                  ),
              ],
            ),
          ),
          if (vm.doCache)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('Exibindo dados salvos no aparelho (sem conexão).'),
            ),
          Expanded(child: _lista(context, vm, podeEditar: podeEditar, podeExcluir: podeExcluir)),
        ],
      ),
    );
  }

  Widget _lista(BuildContext context, ProdutosViewModel vm, {required bool podeEditar, required bool podeExcluir}) {
    if (vm.carregando) return const LoadingView();
    if (vm.erro != null) return ErrorView(message: vm.erro!, onRetry: vm.recarregar);
    if (vm.vazio) {
      final buscando = vm.busca.isNotEmpty || vm.filtro != FiltroEstoque.todos;
      return RefreshIndicator(
        onRefresh: vm.recarregar,
        child: EmptyView(
          icon: buscando ? Icons.search_off : Icons.inventory_2_outlined,
          title: buscando ? 'Nenhum produto encontrado' : 'Nenhum produto cadastrado',
          message: buscando
              ? 'Tente outro termo ou filtro.'
              : (podeEditar ? 'Cadastre o primeiro produto da sua loja.' : 'Peça ao gerente para cadastrar produtos.'),
          action: !buscando && podeEditar
              ? CeiButton(
                  label: 'Cadastrar produto',
                  icon: Icons.add,
                  expand: false,
                  onPressed: () => _novoProduto(context),
                )
              : null,
        ),
      );
    }

    return PagedListView<Produto>(
      items: vm.itens,
      keyOf: (p) => p.id,
      hasMore: vm.temMais,
      isLoadingMore: vm.carregandoMais,
      onLoadMore: vm.carregarMais,
      onRefresh: vm.recarregar,
      itemBuilder: (context, produto) {
        final card = ProdutoCard(produto: produto, onTap: () => _abrir(context, produto));
        if (!podeExcluir) return card;
        return Dismissible(
          key: ValueKey('dismiss-${produto.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmarExclusao(context, produto),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: AppRadius.mdAll,
            ),
            child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
          ),
          child: card,
        );
      },
    );
  }
}

/// Sinal devolvido pela tela de detalhe quando o produto foi excluído.
enum ProdutoExcluido { sinal }
