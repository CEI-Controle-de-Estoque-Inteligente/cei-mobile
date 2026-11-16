import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../data/remote/brasil_api_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../viewmodels/cadastro_viewmodel.dart';

class CadastroView extends StatelessWidget {
  const CadastroView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CadastroViewModel(
        context.read<AuthRepository>(),
        context.read<BrasilApiService>(),
      ),
      child: const _CadastroForm(),
    );
  }
}

class _CadastroForm extends StatefulWidget {
  const _CadastroForm();

  @override
  State<_CadastroForm> createState() => _CadastroFormState();
}

class _CadastroFormState extends State<_CadastroForm> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();
  final _empresa = TextEditingController();
  final _cnpj = TextEditingController();
  final _codigo = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in [_nome, _email, _senha, _confirmar, _empresa, _cnpj, _codigo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _buscarCnpj() async {
    final erro = Validators.optionalCnpj(_cnpj.text);
    if (_cnpj.text.isEmpty || erro != null) {
      AppFeedback.error(context, erro ?? 'Digite o CNPJ para buscar');
      return;
    }
    final vm = context.read<CadastroViewModel>();
    final nome = await vm.consultarCnpj(_cnpj.text);
    if (!mounted) return;
    if (nome != null) {
      _empresa.text = nome;
      AppFeedback.success(context, 'Empresa encontrada: $nome');
    } else if (vm.erro != null) {
      AppFeedback.error(context, vm.erro!);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<CadastroViewModel>();
    final novaEmpresa = vm.modo == ModoCadastro.novaEmpresa;

    final resultado = await vm.cadastrar(
      DadosCadastro(
        nome: _nome.text,
        email: _email.text,
        senha: _senha.text,
        empresaNome: novaEmpresa ? _empresa.text : null,
        cnpj: novaEmpresa && _cnpj.text.isNotEmpty ? Formatters.onlyDigits(_cnpj.text) : null,
        codigoEmpresa: novaEmpresa ? null : _codigo.text,
      ),
    );
    if (!mounted) return;

    switch (resultado) {
      case ResultadoCadastro.logado:
        setState(() => _dirty = false);
        AppFeedback.success(context, 'Conta criada! Bem-vindo(a) ao CEI.');
      case ResultadoCadastro.confirmarEmail:
        setState(() => _dirty = false);
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.mark_email_read_outlined),
            title: const Text('Confirme seu e-mail'),
            content: Text(
              'Enviamos um link de confirmação para ${_email.text.trim()}. '
              'Depois de confirmar, volte e entre com seu e-mail e senha.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
        if (mounted) context.pop();
      case ResultadoCadastro.erro:
        AppFeedback.error(context, vm.erro ?? 'Não foi possível criar a conta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CadastroViewModel>();
    final novaEmpresa = vm.modo == ModoCadastro.novaEmpresa;
    final textTheme = Theme.of(context).textTheme;

    return UnsavedChangesGuard(
      hasChanges: _dirty && !vm.salvando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Criar conta')),
        body: ResponsiveBody(
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<ModoCadastro>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ModoCadastro.novaEmpresa,
                        icon: Icon(Icons.store_outlined),
                        label: Text('Sou o gerente'),
                      ),
                      ButtonSegment(
                        value: ModoCadastro.entrarEmEmpresa,
                        icon: Icon(Icons.badge_outlined),
                        label: Text('Sou funcionário'),
                      ),
                    ],
                    selected: {vm.modo},
                    onSelectionChanged: vm.salvando ? null : (s) => vm.alterarModo(s.first),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    novaEmpresa
                        ? 'Você cria a empresa e entra como Gerente. Depois compartilha o código com a equipe.'
                        : 'Use o código de 6 caracteres que o gerente da empresa compartilhou com você.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CeiTextField(
                    controller: _nome,
                    label: 'Seu nome',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: Validators.name,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CeiTextField(
                    controller: _email,
                    label: 'E-mail',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CeiTextField(
                    controller: _senha,
                    label: 'Senha',
                    helper: 'Mínimo de 8 caracteres, com letras e números',
                    prefixIcon: Icons.lock_outline,
                    obscureText: vm.obscure,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.strongPassword,
                    suffix: IconButton(
                      tooltip: vm.obscure ? 'Mostrar senha' : 'Ocultar senha',
                      icon: Icon(vm.obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: vm.alternarSenha,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CeiTextField(
                    controller: _confirmar,
                    label: 'Confirmar senha',
                    prefixIcon: Icons.lock_outline,
                    obscureText: vm.obscure,
                    textInputAction: TextInputAction.next,
                    validator: Validators.confirmPassword(() => _senha.text),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (novaEmpresa) ...[
                    CeiTextField(
                      controller: _cnpj,
                      label: 'CNPJ (opcional)',
                      hint: '00.000.000/0000-00',
                      prefixIcon: Icons.business_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CnpjInputFormatter()],
                      validator: Validators.optionalCnpj,
                      suffix: vm.consultandoCnpj
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Buscar dados do CNPJ',
                              icon: const Icon(Icons.travel_explore),
                              onPressed: _buscarCnpj,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CeiTextField(
                      controller: _empresa,
                      label: 'Nome da empresa',
                      prefixIcon: Icons.store_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => Validators.notEmpty(v, message: 'Informe o nome da empresa'),
                    ),
                  ] else ...[
                    CeiTextField(
                      controller: _codigo,
                      label: 'Código da empresa',
                      hint: 'Ex.: A1B2C3',
                      prefixIcon: Icons.key_outlined,
                      textCapitalization: TextCapitalization.characters,
                      validator: Validators.companyCode,
                      onChanged: (_) => vm.codigoAlterado(),
                      suffix: vm.verificandoCodigo
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Verificar código',
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                if (Validators.companyCode(_codigo.text) == null) {
                                  vm.verificarCodigo(_codigo.text);
                                }
                              },
                            ),
                    ),
                    if (vm.empresaDoCodigo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'Empresa: ${vm.empresaDoCodigo}',
                          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (vm.erro != null && !vm.salvando)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          vm.erro!,
                          style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  CeiButton(
                    label: 'Criar conta',
                    icon: Icons.check,
                    isLoading: vm.salvando,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Ao criar a conta você concorda com o uso dos seus dados apenas para o '
                    'funcionamento do CEI, conforme a LGPD.',
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
