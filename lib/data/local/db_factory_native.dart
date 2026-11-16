import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

DatabaseFactory get plataformaDatabaseFactory => databaseFactorySqflitePlugin;

Future<String> caminhoBanco(String nome) async {
  final dir = await getDatabasesPath();
  return p.join(dir, nome);
}
