import '../../../core/errors/app_exception.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/venda.dart';
import '../../../data/repositories/resultados.dart';
import '../../../data/repositories/venda_repository.dart';
import '../../../shared/viewmodels/paginated_viewmodel.dart';

/// Minhas Vendas: histórico paginado + resumo do período (ticket médio).
/// O isolamento entre operadores é garantido pelo RLS no banco.
class VendasViewModel extends PaginatedViewModel<Venda> {
  VendasViewModel(this._repository, this.perfil);

  final VendaRepository _repository;
  final Perfil perfil;

  PeriodoVendas _periodo = PeriodoVendas.hoje;
  IntervaloDatas _intervalo = IntervaloDatas.de(PeriodoVendas.hoje);
  ResumoVendas _resumo = ResumoVendas.vazio;
  bool _somenteMinhas = false;

  PeriodoVendas get periodo => _periodo;
  IntervaloDatas get intervalo => _intervalo;
  ResumoVendas get resumo => _resumo;
  bool get somenteMinhas => _somenteMinhas;
  bool get veTodas => perfil.pode(Modulo.vendasTodas);

  String? get _operadorFiltro => veTodas && _somenteMinhas ? perfil.id : null;

  @override
  Future<Pagina<Venda>> buscarPagina(int pagina) =>
      _repository.listar(intervalo: _intervalo, operadorId: _operadorFiltro, pagina: pagina);

  @override
  Future<void> recarregar() async {
    await Future.wait([super.recarregar(), _carregarResumo()]);
  }

  Future<void> _carregarResumo() async {
    try {
      _resumo = await _repository.resumo(intervalo: _intervalo, operadorId: _operadorFiltro);
    } on AppException {
      _resumo = ResumoVendas.vazio;
    }
    notificar();
  }

  void alterarPeriodo(PeriodoVendas periodo, {IntervaloDatas? personalizado}) {
    _periodo = periodo;
    _intervalo = personalizado ?? IntervaloDatas.de(periodo);
    recarregar();
  }

  void alternarSomenteMinhas(bool valor) {
    _somenteMinhas = valor;
    recarregar();
  }

  void vendaRegistrada() => recarregar();
}
