import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/network/connectivity_service.dart';
import '../local/pendencias_local_datasource.dart';
import '../models/operacao_pendente.dart';
import 'produto_repository.dart';
import 'venda_repository.dart';

/// Envia a fila de operações offline quando a conexão volta (C4.4 / C4.7).
///
/// Conflitos: o servidor é a fonte da verdade. Se uma operação for
/// rejeitada (ex.: estoque insuficiente porque outro aparelho vendeu antes),
/// ela fica marcada com o erro para o usuário revisar ou descartar.
class SyncService extends ChangeNotifier {
  SyncService({
    required PendenciasLocalDataSource pendencias,
    required ProdutoRepositoryImpl produtos,
    required VendaRepositoryImpl vendas,
    required ConnectivityService connectivity,
  }) : _pendencias = pendencias,
       _produtos = produtos,
       _vendas = vendas,
       _connectivity = connectivity {
    _connectivity.addListener(_onConnectivityChanged);
  }

  final PendenciasLocalDataSource _pendencias;
  final ProdutoRepositoryImpl _produtos;
  final VendaRepositoryImpl _vendas;
  final ConnectivityService _connectivity;

  List<OperacaoPendente> _itens = const [];
  bool _sincronizando = false;
  bool _wasOnline = true;
  bool _disposed = false;

  List<OperacaoPendente> get itens => _itens;
  int get quantidade => _itens.length;
  bool get sincronizando => _sincronizando;

  Future<void> carregar() async {
    _itens = await _pendencias.listar();
    _notify();
  }

  void _onConnectivityChanged() {
    final online = _connectivity.isOnline;
    if (online && !_wasOnline) sincronizar();
    _wasOnline = online;
  }

  /// Retorna quantas operações foram enviadas com sucesso.
  Future<int> sincronizar() async {
    if (_sincronizando) return 0;
    _sincronizando = true;
    _notify();

    var enviadas = 0;
    try {
      final fila = await _pendencias.listar();
      for (final op in fila) {
        try {
          switch (op.tipo) {
            case TipoOperacao.venda:
              await _vendas.enviarVendaPendente(op.payload);
            case TipoOperacao.movimentacao:
              await _produtos.enviarMovimentacaoPendente(op.payload);
          }
          await _pendencias.remover(op.id!);
          enviadas++;
        } on AppException catch (e) {
          if (ErrorMapper.isNetwork(e)) break; // continua offline: tenta depois
          await _pendencias.registrarFalha(op.id!, e.message);
        }
      }
    } finally {
      _sincronizando = false;
      await carregar();
    }
    return enviadas;
  }

  Future<void> descartar(OperacaoPendente op) async {
    await _pendencias.remover(op.id!);
    await carregar();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
