import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/perfil.dart';
import '../../../data/models/produto.dart';
import '../../../data/remote/open_food_facts_service.dart';
import '../../../data/repositories/produto_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/produto_form_viewmodel.dart';

/// Cadastro e edição de produto, com proteção contra saída sem salvar.
class ProdutoFormView extends StatelessWidget {
  const ProdutoFormView({super.key, this.inicial});

  final Produto? inicial;

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      create: (context) => ProdutoFormViewModel(
        repository: context.read<ProdutoRepository>(),
        openFoodFacts: context.read<OpenFoodFactsService>(),
        empresaId: perfil.empresaId,
        inicial: inicial,
      ),
      child: _ProdutoForm(inicial: inicial),
    );
  }
}

class _ProdutoForm extends StatefulWidget {
  const _ProdutoForm({this.inicial});

  final Produto? inicial;

  @override
  State<_ProdutoForm> createState() => _ProdutoFormState();
}

class _ProdutoFormState extends State<_ProdutoForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _categoria;
  late final TextEditingController _codigo;
  late final TextEditingController _preco;
  late final TextEditingController _quantidade;
  late final TextEditingController _minimo;
  late final TextEditingController _maximo;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final p = widget.inicial;
    _nome = TextEditingController(text: p?.nome);
    _categoria = TextEditingController(text: p?.categoria);
    _codigo = TextEditingController(text: p?.codigoBarras);
    _preco = TextEditingController(text: p == null ? '' : Formatters.currency(p.preco));
    _quantidade = TextEditingController(text: '0');
    _minimo = TextEditingController(text: '${p?.estoqueMinimo ?? 5}');
    _maximo = TextEditingController(text: '${p?.estoqueMaximo ?? 0}');
  }

  @override
  void dispose() {
    for (final c in [_nome, _categoria, _codigo, _preco, _quantidade, _minimo, _maximo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _marcarAlterado() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _escanear() async {
    final codigo = await context.push<String>(AppRoutes.scanner);
    if (codigo == null || !mounted) return;
    _codigo.text = codigo;
    _marcarAlterado();
    await _buscarCodigo();
  }

  Future<void> _buscarCodigo() async {
    final codigo = _codigo.text.trim();
    if (Validators.optionalBarcode(codigo) != null || codigo.isEmpty) {
      AppFeedback.error(context, 'Digite um código de barras válido para buscar.');
      return;
    }
    final vm = context.read<ProdutoFormViewModel>();
    final externo = await vm.buscarPorCodigo(codigo);
    if (!mounted) return;
    if (externo != null) {
      setState(() {
        if (_nome.text.trim().isEmpty) _nome.text = externo.nomeCompleto;
        if (_categoria.text.trim().isEmpty && externo.categoria != null) {
          _categoria.text = externo.categoria!;
        }
        _dirty = true;
      });
      AppFeedback.success(context, 'Dados preenchidos pela base Open Food Facts.');
    } else if (vm.erro != null) {
      AppFeedback.info(context, vm.erro!);
    }
  }

  Future<void> _escolherValidade() async {
    final vm = context.read<ProdutoFormViewModel>();
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: vm.validade ?? hoje.add(const Duration(days: 30)),
      firstDate: hoje.subtract(const Duration(days: 365)),
      lastDate: hoje.add(const Duration(days: 365 * 5)),
      helpText: 'Data de validade',
    );
    if (data != null) {
      vm.definirValidade(data);
      _marcarAlterado();
    }
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<ProdutoFormViewModel>();
    final produto = await vm.salvar(
      nome: _nome.text,
      categoria: _categoria.text,
      codigoBarras: _codigo.text,
      preco: Formatters.parseCurrency(_preco.text),
      quantidadeInicial: int.tryParse(_quantidade.text) ?? 0,
      estoqueMinimo: int.tryParse(_minimo.text) ?? 0,
      estoqueMaximo: int.tryParse(_maximo.text) ?? 0,
    );
    if (!mounted) return;
    if (produto == null) {
      AppFeedback.error(context, vm.erro ?? 'Não foi possível salvar.');
      return;
    }
    setState(() => _dirty = false);
    AppFeedback.success(context, vm.editando ? 'Produto atualizado.' : 'Produto cadastrado.');
    context.pop(produto);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProdutoFormViewModel>();
    final validade = vm.validade;

    return UnsavedChangesGuard(
      hasChanges: _dirty && !vm.salvando,
      child: Scaffold(
        appBar: AppBar(title: Text(vm.editando ? 'Editar produto' : 'Novo produto')),
        body: ResponsiveBody(
          child: Form(
            key: _formKey,
            onChanged: _marcarAlterado,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CeiTextField(
                  controller: _codigo,
                  label: 'Código de barras (opcional)',
                  prefixIcon: Icons.qr_code_2,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: Validators.optionalBarcode,
                  suffix: vm.buscandoCodigo
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Buscar dados pelo código',
                              icon: const Icon(Icons.travel_explore),
                              onPressed: _buscarCodigo,
                            ),
                            IconButton(
                              tooltip: 'Ler com a câmera',
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _escanear,
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _nome,
                  label: 'Nome do produto',
                  prefixIcon: Icons.label_outline,
                  textCapitalization: TextCapitalization.sentences,
                  validator: Validators.name,
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _categoria,
                  label: 'Categoria (opcional)',
                  hint: 'Ex.: Laticínios, Bebidas',
                  prefixIcon: Icons.category_outlined,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _preco,
                  label: 'Preço unitário',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  validator: Validators.price,
                ),
                const SizedBox(height: AppSpacing.md),
                if (!vm.editando) ...[
                  CeiTextField(
                    controller: _quantidade,
                    label: 'Quantidade inicial',
                    helper: 'Depois do cadastro, a quantidade muda só por entradas, saídas e vendas.',
                    prefixIcon: Icons.numbers,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => Validators.integer(v, field: 'Quantidade'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CeiTextField(
                        controller: _minimo,
                        label: 'Estoque mínimo',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => Validators.integer(v, field: 'Mínimo'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: CeiTextField(
                        controller: _maximo,
                        label: 'Capacidade máx.',
                        helper: '0 = sem limite',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => Validators.integer(v, field: 'Capacidade'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Validade'),
                    subtitle: Text(
                      validade == null ? 'Produto sem controle de validade' : Formatters.date(validade),
                    ),
                    onTap: _escolherValidade,
                    trailing: validade == null
                        ? const Icon(Icons.edit_calendar_outlined)
                        : IconButton(
                            tooltip: 'Remover validade',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              vm.definirValidade(null);
                              _marcarAlterado();
                            },
                          ),
                  ),
                ),
                if (vm.erro != null && !vm.buscandoCodigo) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(vm.erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.lg),
                CeiButton(
                  label: vm.editando ? 'Salvar alterações' : 'Cadastrar produto',
                  icon: Icons.check,
                  isLoading: vm.salvando,
                  onPressed: _salvar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
