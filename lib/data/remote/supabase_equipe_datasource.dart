import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_resumo.dart';
import '../models/perfil.dart';
import '../models/tabela_descontos.dart';

class SupabaseEquipeDataSource {
  SupabaseEquipeDataSource(this._client);

  final SupabaseClient _client;
  static const Duration _timeout = Duration(seconds: 12);

  Future<List<Perfil>> listar() async {
    final rows = await _client.from('perfis').select().order('nome').timeout(_timeout);
    return rows.map(Perfil.fromJson).toList();
  }

  /// Só o gerente (validado no banco pela RPC).
  Future<TabelaDescontos> atualizarDescontos(TabelaDescontos t) async {
    final result = await _client
        .rpc<Map<String, dynamic>>(
          'atualizar_descontos',
          params: {
            'p_1d': t.ate1Dia,
            'p_3d': t.ate3Dias,
            'p_5d': t.ate5Dias,
            'p_6d': t.ate6Dias,
          },
        )
        .timeout(_timeout);
    return TabelaDescontos.fromJson(result);
  }

  Future<Perfil> atualizar(Perfil perfil) async {
    final row = await _client
        .from('perfis')
        .update(perfil.toUpdateJson())
        .eq('id', perfil.id)
        .select()
        .single()
        .timeout(_timeout);
    return Perfil.fromJson(row);
  }
}

class SupabaseDashboardDataSource {
  SupabaseDashboardDataSource(this._client);

  final SupabaseClient _client;
  static const Duration _timeout = Duration(seconds: 12);

  Future<DashboardResumo> resumo() async {
    final result = await _client.rpc<Map<String, dynamic>>('dashboard_resumo').timeout(_timeout);
    return DashboardResumo.fromJson(result);
  }

  Future<List<GiroProduto>> giro({int dias = 30}) async {
    final result = await _client
        .rpc<List<dynamic>>('giro_produtos', params: {'p_dias': dias})
        .timeout(_timeout);
    return result.whereType<Map<String, dynamic>>().map(GiroProduto.fromJson).toList();
  }
}
