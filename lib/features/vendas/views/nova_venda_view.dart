import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../data/repositories/sync_service.dart';
import '../../../data/repositories/venda_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/search_field.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/nova_venda_viewmodel.dart';

class NovaVendaView extends StatelessWidget {
  const NovaVendaView({super.key, this.produtoInicial});

  final Produto? produtoInicial;

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      create: (context) => NovaVendaViewModel(
        produtos: context.read<ProdutoRepository>(),
        vendas: context.read<VendaRepository>(),
        perfil: perfil,
        produtoInicial: produtoInicial,
      )..carregarIniciais(),
      child: const _NovaVendaBody(),
    );
  }
}

class _NovaVendaBody extends StatelessWidget {
  const _NovaVendaBody();

  Future<void> _escanear(BuildContext context) async {
    final vm = context.read<NovaVendaViewModel>();
    final codigo = await context.push<String>(AppRoutes.scanner);
    if (codigo == null) return;
    final ok = await vm.selecionarPorCodigo(codigo);
    if (!ok && context.mounted) AppFeedback.error(context, vm.erro!);
  }

  Future<void> _confirmar(BuildContext context) async {
    final vm = context.read<NovaVendaViewModel>();
    final sync = context.read<SyncService>();
    final resultado = await vm.confirmar();
    if (!context.mounted) return;
    if (resultado == null) {
      AppFeedback.error(context, vm.erro ?? 'Não foi possível registrar a venda.');
      return;
    }
    if (resultado.pendente) {
      await sync.carregar();
      if (!context.mounted) return;
      AppFeedback.info(context, 'Sem conexão: venda salva no aparelho e será enviada automaticamente.');
    } else {
      AppFeedback.success(context, 'Venda de ${Formatters.currency(resultado.valor.total)} registrada!');
    }
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NovaVendaViewModel>();
    final selecionado = vm.selecionado;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova venda'),
        actions: [
          IconButton(
            tooltip: 'Ler código de barras',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _escanear(context),
          ),
        ],
      ),
      body: selecionado == null ? _Busca(vm: vm) : _Resumo(vm: vm, produto: selecionado),
      bottomNavigationBar: selecionado == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: CeiButton(
                  label: 'Confirmar venda • ${Formatters.currency(vm.total)}',
                  icon: Icons.check,
                  isLoading: vm.salvando,
                  onPressed: vm.podeConfirmar ? () => _confirmar(context) : null,
                ),
              ),
            ),
    );
  }
}

class _Busca extends StatelessWidget {
  const _Busca({required this.vm});

  final NovaVendaViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SearchField(hint: 'Buscar produto para vender', onChanged: vm.buscar),
        ),
        if (vm.buscando) const LinearProgressIndicator(),
        Expanded(
          child: vm.erro != null && vm.resultados.isEmpty
              ? ErrorView(message: vm.erro!, onRetry: vm.carregarIniciais)
              : vm.resultados.isEmpty && !vm.buscando
              ? const EmptyView(
                  icon: Icons.search_off,
                  title: 'Nenhum produto disponível',
                  message: 'Busque pelo nome ou leia o código de barras.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: vm.resultados.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = vm.resultados[i];
                    return ListTile(
                      key: ValueKey(p.id),
                      title: Text(p.nome),
                      subtitle: Text('${p.quantidade} un. disponíveis'),
                      trailing: Text(Formatters.currency(p.preco)),
                      onTap: () => vm.selecionar(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.vm, required this.produto});

  final NovaVendaViewModel vm;
  final Produto produto;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(produto.nome, style: textTheme.titleLarge)),
                    StatusBadge.estoque(context, produto.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('${Formatters.currency(produto.preco)} / un. • ${produto.quantidade} em estoque'),
                if (produto.descontoSugerido() != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'Dica: vence em ${produto.diasParaVencer()} dia(s). '
                      'Sugestão de ${produto.descontoSugerido()}% de desconto.',
                      style: textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  onPressed: vm.limparSelecao,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Trocar produto'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Quantidade', style: textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Diminuir',
              iconSize: 28,
              onPressed: vm.quantidade > 1 ? () => vm.alterarQuantidade(-1) : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Semantics(
                label: 'Quantidade ${vm.quantidade}',
                child: Text('${vm.quantidade}', style: textTheme.displaySmall),
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Aumentar',
              iconSize: 28,
              onPressed: vm.quantidade < produto.quantidade ? () => vm.alterarQuantidade(1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(child: Text('Total: ${Formatters.currency(vm.total)}', style: textTheme.headlineSmall)),
        if (vm.erro != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              vm.erro!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
