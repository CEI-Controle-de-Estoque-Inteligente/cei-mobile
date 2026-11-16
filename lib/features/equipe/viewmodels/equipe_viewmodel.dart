import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/equipe_repository.dart';

class EquipeViewModel extends ChangeNotifier {
  EquipeViewModel(this._repository);

  final EquipeRepository _repository;

  List<Perfil> _equipe = const [];
  bool _carregando = true;
  String? _erro;
  String _busca = '';
  bool _disposed = false;

  bool get carregando => _carregando;
  String? get erro => _erro;

  List<Perfil> get equipe {
    final termo = _busca.trim().toLowerCase();
    if (termo.isEmpty) return _equipe;
    return _equipe
        .where((p) => p.nome.toLowerCase().contains(termo) || p.cargo.label.toLowerCase().contains(termo))
        .toList();
  }

  int get ativos => _equipe.where((p) => p.ativo && p.status == StatusFuncionario.ativo).length;

  Future<void> carregar() async {
    _carregando = _equipe.isEmpty;
    _erro = null;
    _notify();
    try {
      _equipe = await _repository.listar();
    } on AppException catch (e) {
      _erro = e.message;
    } finally {
      _carregando = false;
      _notify();
    }
  }

  void buscar(String texto) {
    _busca = texto;
    _notify();
  }

  void atualizado(Perfil perfil) {
    _equipe = [for (final p in _equipe) p.id == perfil.id ? perfil : p];
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

class FuncionarioFormViewModel extends ChangeNotifier {
  FuncionarioFormViewModel(this._repository, this.original) : _editado = original;

  final EquipeRepository _repository;
  final Perfil original;

  Perfil _editado;
  bool _salvando = false;
  String? _erro;
  bool _disposed = false;

  Perfil get editado => _editado;
  bool get salvando => _salvando;
  String? get erro => _erro;

  bool get alterado =>
      _editado.cargo != original.cargo ||
      _editado.turno != original.turno ||
      _editado.status != original.status ||
      _editado.ativo != original.ativo;

  void alterar({Cargo? cargo, Turno? turno, StatusFuncionario? status, bool? ativo}) {
    _editado = _editado.copyWith(cargo: cargo, turno: turno, status: status, ativo: ativo);
    _notify();
  }

  Future<Perfil?> salvar() async {
    _salvando = true;
    _erro = null;
    _notify();
    try {
      return await _repository.atualizar(_editado);
    } on AppException catch (e) {
      _erro = e.message;
      return null;
    } finally {
      _salvando = false;
      _notify();
    }
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
