import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json_utils.dart';
import '../models/movimentacao.dart';
import '../models/produto.dart';

enum FiltroEstoque {
  todos('Todos'),
  criticos('Estoque baixo'),
  vencendo('Vencendo (30 dias)');

  const FiltroEstoque(this.label);

  final String label;
}

/// Acesso remoto a produtos e movimentações (Supabase / PostgREST).
class SupabaseProdutoDataSource {
  SupabaseProdutoDataSource(this._client);

  final SupabaseClient _client;
  static const Duration _timeout = Duration(seconds: 12);

  Future<List<Produto>> listar({
    required String empresaId,
    required String busca,
    required FiltroEstoque filtro,
    required int offset,
    required int limite,
  }) async {
    var query = _client
        .from('produtos')
        .select()
        .eq('empresa_id', empresaId)
        .eq('ativo', true);

    final termo = _sanitizar(busca);
    if (termo.isNotEmpty) {
      query = query.or('nome.ilike.%$termo%,codigo_barras.eq.$termo');
    }
    if (filtro == FiltroEstoque.criticos) {
      query = query.inFilter('status', ['critico', 'baixo']);
    }
    if (filtro == FiltroEstoque.vencendo) {
      final limiteData = DateTime.now().add(const Duration(days: 30));
      query = query.not('validade', 'is', null).lte('validade', JsonUtils.dateOnly(limiteData));
    }

    final rows = await query
        .order(filtro == FiltroEstoque.vencendo ? 'validade' : 'nome', ascending: true)
        .range(offset, offset + limite - 1)
        .timeout(_timeout);
    return rows.map(Produto.fromJson).toList();
  }

  Future<Produto> buscarPorId(String id) async {
    final row = await _client.from('produtos').select().eq('id', id).single().timeout(_timeout);
    return Produto.fromJson(row);
  }

  Future<Produto?> buscarPorCodigo(String empresaId, String codigo) async {
    final row = await _client
        .from('produtos')
        .select()
        .eq('empresa_id', empresaId)
        .eq('codigo_barras', codigo)
        .eq('ativo', true)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : Produto.fromJson(row);
  }

  Future<Produto> criar(Produto produto) async {
    final row = await _client
        .from('produtos')
        .insert(produto.toJson(incluirQuantidade: true))
        .select()
        .single()
        .timeout(_timeout);
    return Produto.fromJson(row);
  }

  Future<Produto> atualizar(Produto produto) async {
    final row = await _client
        .from('produtos')
        .update(produto.toJson())
        .eq('id', produto.id)
        .select()
        .single()
        .timeout(_timeout);
    return Produto.fromJson(row);
  }

  Future<void> definirAtivo(String id, {required bool ativo}) async {
    await _client.from('produtos').update({'ativo': ativo}).eq('id', id).timeout(_timeout);
  }

  Future<Produto> movimentar({
    required String operacaoId,
    required String produtoId,
    required TipoMovimentacao tipo,
    required int quantidade,
    String? observacao,
  }) async {
    final result = await _client
        .rpc<Map<String, dynamic>>(
          'registrar_movimentacao',
          params: {
            'p_id': operacaoId,
            'p_produto': produtoId,
            'p_tipo': tipo.name,
            'p_quantidade': quantidade,
            'p_observacao': observacao,
          },
        )
        .timeout(_timeout);
    return Produto.fromJson(result);
  }

  /// [percentual] 0 encerra a promoção. Só o gerente (validado no banco).
  Future<Produto> aplicarPromocao(String produtoId, int percentual) async {
    final result = await _client
        .rpc<Map<String, dynamic>>(
          'aplicar_promocao',
          params: {'p_produto': produtoId, 'p_percentual': percentual},
        )
        .timeout(_timeout);
    return Produto.fromJson(result);
  }

  Future<List<Movimentacao>> historico(String produtoId, {required int offset, required int limite}) async {
    final rows = await _client
        .from('movimentacoes')
        .select('*, perfis(nome)')
        .eq('produto_id', produtoId)
        .order('created_at', ascending: false)
        .range(offset, offset + limite - 1)
        .timeout(_timeout);
    return rows.map(Movimentacao.fromJson).toList();
  }

  Future<int> popularDemo() async {
    final result = await _client.rpc<int>('popular_demo').timeout(_timeout);
    return result;
  }

  /// Remove caracteres que quebrariam a sintaxe do filtro `or` do PostgREST.
  static String _sanitizar(String texto) =>
      texto.trim().replaceAll(RegExp(r'[,()%*\\]'), ' ').replaceAll(RegExp(r'\s+'), ' ');
}
