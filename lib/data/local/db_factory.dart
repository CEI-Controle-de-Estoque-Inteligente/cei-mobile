// Seleciona a implementação do sqflite conforme a plataforma:
// celular/desktop usam o plugin nativo; web usa SQLite em WebAssembly.
export 'db_factory_native.dart' if (dart.library.js_interop) 'db_factory_web.dart';
