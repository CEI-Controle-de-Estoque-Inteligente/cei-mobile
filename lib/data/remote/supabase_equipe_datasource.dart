import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_resumo.dart';
import '../models/perfil.dart';

class SupabaseEquipeDataSource {
  SupabaseEquipeDataSource(this._client);

  final SupabaseClient _client;
  static const Duration _timeout = Duration(seconds: 12);

  Future<List<Perfil>> listar() async {
    final rows = await _client.from('perfis').select().order('nome').timeout(_timeout);
    return rows.map(Perfil.fromJson).toList();
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
