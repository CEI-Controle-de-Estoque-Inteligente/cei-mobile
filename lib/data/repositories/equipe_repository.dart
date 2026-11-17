import '../../core/errors/error_mapper.dart';
import '../models/dashboard_resumo.dart';
import '../models/perfil.dart';
import '../models/tabela_descontos.dart';
import '../remote/supabase_equipe_datasource.dart';

class EquipeRepository {
  EquipeRepository(this._remote);

  final SupabaseEquipeDataSource _remote;

  Future<List<Perfil>> listar() async {
    try {
      return await _remote.listar();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<TabelaDescontos> atualizarDescontos(TabelaDescontos tabela) async {
    try {
      return await _remote.atualizarDescontos(tabela);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<Perfil> atualizar(Perfil perfil) async {
    try {
      return await _remote.atualizar(perfil);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}

class DashboardRepository {
  DashboardRepository(this._remote);

  final SupabaseDashboardDataSource _remote;

  Future<DashboardResumo> resumo() async {
    try {
      return await _remote.resumo();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<GiroProduto>> giro({int dias = 30}) async {
    try {
      return await _remote.giro(dias: dias);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
