import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/models/tabela_descontos.dart';
import '../../../data/repositories/equipe_repository.dart';
import '../../../shared/descontos_context.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../auth/viewmodels/session_viewmodel.dart';

/// Tabela de descontos sugeridos (somente gerente).
class DescontosView extends StatefulWidget {
  const DescontosView({super.key});

  @override
  State<DescontosView> createState() => _DescontosViewState();
}

class _DescontosViewState extends State<DescontosView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _d1;
  late final TextEditingController _d3;
  late final TextEditingController _d5;
  late final TextEditingController _d6;
  bool _dirty = false;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    final t = tabelaDescontosDe(context, listen: false);
    _d1 = TextEditingController(text: '${t.ate1Dia}');
    _d3 = TextEditingController(text: '${t.ate3Dias}');
    _d5 = TextEditingController(text: '${t.ate5Dias}');
    _d6 = TextEditingController(text: '${t.ate6Dias}');
  }

  @override
  void dispose() {
    for (final c in [_d1, _d3, _d5, _d6]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _validar(String? texto) {
    final v = int.tryParse(texto?.trim() ?? '');
    if (v == null) return 'Informe um número';
    if (v < 0 || v > TabelaDescontos.maximo) return 'Use de 0% a ${TabelaDescontos.maximo}%';
    return null;
  }

  void _restaurarPadrao() {
    const p = TabelaDescontos.padrao;
    setState(() {
      _d1.text = '${p.ate1Dia}';
      _d3.text = '${p.ate3Dias}';
      _d5.text = '${p.ate5Dias}';
      _d6.text = '${p.ate6Dias}';
      _dirty = true;
    });
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = context.read<EquipeRepository>();
    final session = context.read<SessionViewModel>();
    setState(() => _salvando = true);
    try {
      await repo.atualizarDescontos(
        TabelaDescontos(
          ate1Dia: int.parse(_d1.text),
          ate3Dias: int.parse(_d3.text),
          ate5Dias: int.parse(_d5.text),
          ate6Dias: int.parse(_d6.text),
        ),
      );
      await session.recarregarPerfil();
      if (!mounted) return;
      setState(() => _dirty = false);
      AppFeedback.success(context, 'Tabela de descontos salva.');
      context.pop();
    } on AppException catch (e) {
      if (mounted) AppFeedback.error(context, e.message);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(TextEditingController c, String label) {
    return CeiTextField(
      controller: c,
      label: label,
      prefixIcon: Icons.percent,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
      validator: _validar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return UnsavedChangesGuard(
      hasChanges: _dirty && !_salvando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tabela de descontos')),
        body: ResponsiveBody(
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Defina quanto de desconto o CEI deve sugerir para produtos perto do vencimento. '
                  'Use 0 para não sugerir naquela faixa. A sugestão aparece no estoque, no dashboard e no '
                  'assistente; o desconto só vale nas vendas depois que você aplicar a promoção no produto.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                _campo(_d1, 'Vence hoje ou amanhã'),
                const SizedBox(height: AppSpacing.md),
                _campo(_d3, 'Vence em 2 ou 3 dias'),
                const SizedBox(height: AppSpacing.md),
                _campo(_d5, 'Vence em 4 ou 5 dias'),
                const SizedBox(height: AppSpacing.md),
                _campo(_d6, 'Vence em 6 dias'),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _salvando ? null : _restaurarPadrao,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restaurar padrão (50, 30, 20 e 10%)'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CeiButton(label: 'Salvar', icon: Icons.check, isLoading: _salvando, onPressed: _salvar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
