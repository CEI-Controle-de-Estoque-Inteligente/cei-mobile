import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'db_factory.dart';

/// Acesso único ao banco local (Singleton) com versionamento de schema (C4.2).
///
/// v1: cache de produtos.
/// v2: fila de operações pendentes (vendas/movimentações feitas offline).
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _nomeBanco = 'cei_mobile.db';
  static const int _versao = 2;

  Database? _database;
  Completer<Database>? _abrindo;

  Future<Database> get database async {
    final aberto = _database;
    if (aberto != null) return aberto;

    // Evita abrir o banco duas vezes se houver chamadas simultâneas.
    final emAndamento = _abrindo;
    if (emAndamento != null) return emAndamento.future;

    final completer = Completer<Database>();
    _abrindo = completer;
    try {
      final db = await _abrir();
      _database = db;
      completer.complete(db);
      return db;
    } catch (e, s) {
      completer.completeError(e, s);
      rethrow;
    } finally {
      _abrindo = null;
    }
  }

  Future<Database> _abrir() async {
    final factory = plataformaDatabaseFactory;
    final caminho = await caminhoBanco(_nomeBanco);
    return factory.openDatabase(
      caminho,
      options: OpenDatabaseOptions(
        version: _versao,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _criarV1(db);
    await _criarV2(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _criarV2(db);
  }

  Future<void> _criarV1(Database db) async {
    await db.execute('''
      CREATE TABLE produtos (
        id TEXT PRIMARY KEY,
        empresa_id TEXT NOT NULL,
        nome TEXT NOT NULL,
        nome_busca TEXT NOT NULL,
        categoria TEXT,
        codigo_barras TEXT,
        preco REAL NOT NULL,
        quantidade INTEGER NOT NULL,
        estoque_minimo INTEGER NOT NULL,
        estoque_maximo INTEGER NOT NULL,
        validade TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_produtos_busca ON produtos (empresa_id, nome_busca)');
  }

  Future<void> _criarV2(Database db) async {
    await db.execute('''
      CREATE TABLE operacoes_pendentes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        payload TEXT NOT NULL,
        criada_em TEXT NOT NULL,
        tentativas INTEGER NOT NULL DEFAULT 0,
        erro TEXT
      )
    ''');
  }

  /// Usado no logout: os dados de uma empresa não ficam no aparelho.
  Future<void> limparTudo() async {
    final db = await database;
    await db.delete('produtos');
    await db.delete('operacoes_pendentes');
  }
}
