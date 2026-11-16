import 'package:sqflite/sqflite.dart';

import '../models/produto.dart';
import 'database_helper.dart';

/// CRUD local dos produtos (cache para uso offline - C4.1).
class ProdutoLocalDataSource {
  ProdutoLocalDataSource([DatabaseHelper? helper])
    : _helper = helper ?? DatabaseHelper.instance;

  final DatabaseHelper _helper;
  static const String _tabela = 'produtos';

  Future<void> salvarTodos(List<Produto> produtos) async {
    if (produtos.isEmpty) return;
    final db = await _helper.database;
    final batch = db.batch();
    for (final produto in produtos) {
      batch.insert(_tabela, produto.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> salvar(Produto produto) => salvarTodos([produto]);

  Future<Produto?> buscarPorId(String id) async {
    final db = await _helper.database;
    final rows = await db.query(_tabela, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Produto.fromMap(rows.first);
  }

  Future<Produto?> buscarPorCodigo(String empresaId, String codigo) async {
    final db = await _helper.database;
    final rows = await db.query(
      _tabela,
      where: 'empresa_id = ? AND codigo_barras = ? AND ativo = 1',
      whereArgs: [empresaId, codigo],
      limit: 1,
    );
    return rows.isEmpty ? null : Produto.fromMap(rows.first);
  }

  /// Listagem paginada com busca e filtro - mesma semântica da remota.
  Future<List<Produto>> listar({
    required String empresaId,
    String busca = '',
    int offset = 0,
    int limite = 20,
    bool somenteCriticos = false,
    DateTime? validadeAte,
  }) async {
    final db = await _helper.database;
    final where = StringBuffer('empresa_id = ? AND ativo = 1');
    final args = <Object?>[empresaId];

    if (busca.trim().isNotEmpty) {
      where.write(' AND (nome_busca LIKE ? OR codigo_barras = ?)');
      args
        ..add('%${busca.trim().toLowerCase()}%')
        ..add(busca.trim());
    }
    if (somenteCriticos) {
      where.write(' AND (quantidade = 0 OR quantidade <= estoque_minimo)');
    }
    if (validadeAte != null) {
      where.write(' AND validade IS NOT NULL AND validade <= ?');
      args.add(validadeAte.toIso8601String().substring(0, 10));
    }

    final rows = await db.query(
      _tabela,
      where: where.toString(),
      whereArgs: args,
      orderBy: validadeAte != null ? 'validade ASC' : 'nome_busca ASC',
      limit: limite,
      offset: offset,
    );
    return rows.map(Produto.fromMap).toList();
  }

  Future<void> remover(String id) async {
    final db = await _helper.database;
    await db.delete(_tabela, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contar(String empresaId) async {
    final db = await _helper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_tabela WHERE empresa_id = ? AND ativo = 1',
      [empresaId],
    );
    return (result.first['total'] as int?) ?? 0;
  }
}
