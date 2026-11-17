import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/dashboard_resumo.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/models/tabela_descontos.dart';
import '../../../data/repositories/equipe_repository.dart';
import '../../../data/repositories/produto_repository.dart';

enum TipoRecomendacao { repor, desconto, aumentarPedido }

class Recomendacao {
  const Recomendacao(this.tipo, this.titulo, this.detalhe, {this.produtoId});

  final TipoRecomendacao tipo;
  final String titulo;
  final String detalhe;
  final String? produtoId;
}

/// Gera as recomendações automáticas do dashboard (RN003).
/// Função pura, coberta por testes.
List<Recomendacao> gerarRecomendacoes({
  required List<Produto> criticos,
  required List<Produto> vencendo,
  List<GiroProduto> giro = const [],
  TabelaDescontos tabela = TabelaDescontos.padrao,
}) {
  final recomendacoes = <Recomendacao>[];
  for (final p in vencendo) {
    final desconto = p.descontoSugerido(tabela: tabela);
    if (desconto != null) {
      recomendacoes.add(
        Recomendacao(
          TipoRecomendacao.desconto,
          'Aplicar $desconto% de desconto em ${p.nome}',
          'Vence em ${p.diasParaVencer()} dia(s) e ainda há ${p.quantidade} un.',
          produtoId: p.id,
        ),
      );
    }
  }
  for (final p in criticos) {
    final repor = (p.estoqueMaximo > 0 ? p.estoqueMaximo : p.estoqueMinimo * 2) - p.quantidade;
    recomendacoes.add(
      Recomendacao(
        TipoRecomendacao.repor,
        'Repor ${p.nome}',
        'Restam ${p.quantidade} un. (mínimo ${p.estoqueMinimo}). Sugestão: comprar ${repor > 0 ? repor : p.estoqueMinimo} un.',
        produtoId: p.id,
      ),
    );
  }
  final emAlta = giro.where((g) => g.vendido > 0 && (g.diasCobertura ?? 999) < 10).take(2);
  for (final g in emAlta) {
    if (recomendacoes.any((r) => r.produtoId == g.produtoId)) continue;
    recomendacoes.add(
      Recomendacao(
        TipoRecomendacao.aumentarPedido,
        'Aumentar pedido de ${g.nome}',
        'Alta saída: estoque dura ~${g.diasCobertura!.toStringAsFixed(0)} dia(s) no ritmo atual.',
        produtoId: g.produtoId,
      ),
    );
  }
  return recomendacoes.take(6).toList();
}

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required DashboardRepository dashboard,
    required ProdutoRepository produtos,
    required Perfil perfil,
  }) : _dashboard = dashboard,
       _produtos = produtos,
       _perfil = perfil;

  final DashboardRepository _dashboard;
  final ProdutoRepository _produtos;
  final Perfil _perfil;

  bool _carregando = true;
  String? _erro;
  DashboardResumo? _resumo;
  String? _avisoResumo;
  List<Produto> _vencendo = const [];
  List<Produto> _criticos = const [];
  List<Recomendacao> _recomendacoes = const [];
  bool _doCache = false;
  bool _disposed = false;

  bool get carregando => _carregando;
  String? get erro => _erro;
  DashboardResumo? get resumo => _resumo;
  String? get avisoResumo => _avisoResumo;
  List<Produto> get vencendo => _vencendo;
  List<Produto> get criticos => _criticos;
  List<Recomendacao> get recomendacoes => _recomendacoes;
  bool get doCache => _doCache;
  Perfil get perfil => _perfil;

  Future<void> carregar() async {
    _carregando = _resumo == null && _vencendo.isEmpty;
    _erro = null;
    _notify();

    try {
      final vencendoPagina = await _produtos.listar(
        empresaId: _perfil.empresaId,
        filtro: FiltroEstoque.vencendo,
        tamanho: 15,
      );
      final criticosPagina = await _produtos.listar(
        empresaId: _perfil.empresaId,
        filtro: FiltroEstoque.criticos,
        tamanho: 10,
      );
      _vencendo = vencendoPagina.itens
          .where((p) => (p.diasParaVencer() ?? 999) <= 15 && p.quantidade > 0)
          .toList();
      _criticos = criticosPagina.itens;
      _doCache = vencendoPagina.doCache || criticosPagina.doCache;

      List<GiroProduto> giro = const [];
      try {
        _resumo = await _dashboard.resumo();
        giro = await _dashboard.giro();
        _avisoResumo = null;
      } on AppException catch (e) {
        _avisoResumo = e is NetworkException || e is TimeoutAppException
            ? 'Indicadores em tempo real indisponíveis sem conexão.'
            : e.message;
      }
      _recomendacoes = gerarRecomendacoes(
        criticos: _criticos,
        vencendo: _vencendo,
        giro: giro,
        tabela: _perfil.empresa?.descontos ?? TabelaDescontos.padrao,
      );
    } on AppException catch (e) {
      _erro = e.message;
    } finally {
      _carregando = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
