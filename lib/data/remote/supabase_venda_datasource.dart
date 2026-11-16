import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/venda.dart';

class SupabaseVendaDataSource {
  SupabaseVendaDataSource(this._client);

  final SupabaseClient _client;
  static const Duration _timeout = Duration(seconds: 12);

  Future<Venda> registrar({
    required String vendaId,
    required String produtoId,
    required int quantidade,
  }) async {
    final result = await _client
        .rpc<Map<String, dynamic>>(
          'registrar_venda',
          params: {'p_id': vendaId, 'p_produto': produtoId, 'p_quantidade': quantidade},
        )
        .timeout(_timeout);
    return Venda.fromJson(result);
  }

  /// O RLS garante que operadores só recebam as próprias vendas.
  Future<List<Venda>> listar({
    required IntervaloDatas intervalo,
    required int offset,
    required int limite,
    String? operadorId,
  }) async {
    var query = _client
        .from('vendas')
        .select('*, perfis(nome)')
        .gte('created_at', intervalo.inicio.toUtc().toIso8601String())
        .lt('created_at', intervalo.fim.toUtc().toIso8601String());
    if (operadorId != null) query = query.eq('operador_id', operadorId);

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limite - 1)
        .timeout(_timeout);
    return rows.map(Venda.fromJson).toList();
  }

  Future<ResumoVendas> resumo({required IntervaloDatas intervalo, String? operadorId}) async {
    final result = await _client
        .rpc<Map<String, dynamic>>(
          'resumo_vendas',
          params: {
            'p_inicio': intervalo.inicio.toUtc().toIso8601String(),
            'p_fim': intervalo.fim.toUtc().toIso8601String(),
            'p_operador': operadorId,
          },
        )
        .timeout(_timeout);
    return ResumoVendas.fromJson(result);
  }
}
