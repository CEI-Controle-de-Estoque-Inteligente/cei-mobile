import '../models/operacao_pendente.dart';
import 'database_helper.dart';

/// Fila de operações feitas offline, enviadas quando a conexão volta (C4.4).
class PendenciasLocalDataSource {
  PendenciasLocalDataSource([DatabaseHelper? helper])
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;
  static const String _tabela = 'operacoes_pendentes';

  Future<int> adicionar(OperacaoPendente operacao) async {
    final db = await _helper.database;
    return db.insert(_tabela, operacao.toMap());
  }

  Future<List<OperacaoPendente>> listar() async {
    final db = await _helper.database;
    final rows = await db.query(_tabela, orderBy: 'id ASC');
    return rows.map(OperacaoPendente.fromMap).toList();
  }

  Future<int> contar() async {
    final db = await _helper.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $_tabela');
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<void> registrarFalha(int id, String erro) async {
    final db = await _helper.database;
    await db.rawUpdate(
      'UPDATE $_tabela SET tentativas = tentativas + 1, erro = ? WHERE id = ?',
      [erro, id],
    );
  }

  Future<void> remover(int id) async {
    final db = await _helper.database;
    await db.delete(_tabela, where: 'id = ?', whereArgs: [id]);
  }
}
