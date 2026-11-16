import 'package:flutter/foundation.dart';

import '../../../data/models/perfil.dart';
import '../../../data/repositories/assistente_service.dart';

class MensagemChat {
  MensagemChat({required this.texto, required this.doUsuario}) : hora = DateTime.now();

  final String texto;
  final bool doUsuario;
  final DateTime hora;
}

class AssistenteViewModel extends ChangeNotifier {
  AssistenteViewModel(this._service, this._perfil) {
    _mensagens.add(
      MensagemChat(
        texto: 'Olá, ${_perfil.nome.split(' ').first}! Sou o Assistente CEI. '
            'Pergunte sobre estoque, validades, descontos ou vendas.',
        doUsuario: false,
      ),
    );
  }

  final AssistenteService _service;
  final Perfil _perfil;
  final List<MensagemChat> _mensagens = [];
  bool _respondendo = false;
  bool _disposed = false;

  List<MensagemChat> get mensagens => List.unmodifiable(_mensagens);
  bool get respondendo => _respondendo;
  List<String> get sugestoes => AssistenteService.sugestoes;

  Future<void> enviar(String pergunta) async {
    final texto = pergunta.trim();
    if (texto.isEmpty || _respondendo) return;
    _mensagens.add(MensagemChat(texto: texto, doUsuario: true));
    _respondendo = true;
    _notify();

    final resposta = await _service.responder(texto, _perfil);
    _mensagens.add(MensagemChat(texto: resposta, doUsuario: false));
    _respondendo = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
