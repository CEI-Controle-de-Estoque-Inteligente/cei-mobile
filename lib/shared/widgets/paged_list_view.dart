import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Lista com lazy loading (ListView.separated), scroll infinito e
/// pull-to-refresh (C3.1 / C3.3). Só os itens visíveis são construídos.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.keyOf,
    required this.onLoadMore,
    required this.onRefresh,
    required this.hasMore,
    required this.isLoadingMore,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 96),
    this.separator = const SizedBox(height: AppSpacing.sm),
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Chave estável de cada item (evita reconstruções desnecessárias - C3.5).
  final Object Function(T item) keyOf;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final bool hasMore;
  final bool isLoadingMore;
  final Widget? header;
  final EdgeInsets padding;
  final Widget separator;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.hasMore || widget.isLoadingMore) return;
    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - 300) widget.onLoadMore();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose(); // C2.6
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = widget.header != null;
    final extra = (hasHeader ? 1 : 0) + (widget.hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.items.length + extra,
        separatorBuilder: (context, index) => widget.separator,
        itemBuilder: (context, index) {
          if (hasHeader && index == 0) return widget.header!;
          final i = index - (hasHeader ? 1 : 0);
          if (i >= widget.items.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = widget.items[i];
          return KeyedSubtree(
            key: ValueKey<Object>(widget.keyOf(item)),
            child: widget.itemBuilder(context, item),
          );
        },
      ),
    );
  }
}
