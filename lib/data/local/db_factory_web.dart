import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Requer os arquivos gerados por: dart run sqflite_common_ffi_web:setup
DatabaseFactory get plataformaDatabaseFactory => databaseFactoryFfiWeb;

Future<String> caminhoBanco(String nome) async => nome;
