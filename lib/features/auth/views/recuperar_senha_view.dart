import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../viewmodels/recuperacao_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';

class RecuperarSenhaView extends StatelessWidget {
  const RecuperarSenhaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RecuperacaoViewModel(
        context.read<AuthRepository>(),
        context.read<SessionViewModel>(),
      ),
      child: const _RecuperarSenhaBody(),
    );
  }
}

class _RecuperarSenhaBody extends StatefulWidget {
  const _RecuperarSenhaBody();

  @override
  State<_RecuperarSenhaBody> createState() => _RecuperarSenhaBodyState();
}

class _RecuperarSenhaBodyState extends State<_RecuperarSenhaBody> {
  final _emailForm = GlobalKey<FormState>();
  final _codigoForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _codigo = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _codigo.dispose();
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!(_emailForm.currentState?.validate() ?? false)) return;
    final vm = context.read<RecuperacaoViewModel>();
    final ok = await vm.enviarCodigo(_email.text);
    if (!mounted) return;
    if (ok) {
      AppFeedback.success(context, 'Código enviado para ${vm.email}');
    } else {
      AppFeedback.error(context, vm.erro!);
    }
  }

  Future<void> _redefinir() async {
    if (!(_codigoForm.currentState?.validate() ?? false)) return;
    final vm = context.read<RecuperacaoViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await vm.redefinir(codigo: _codigo.text, novaSenha: _senha.text);
    if (!mounted) {
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Senha alterada com sucesso!')));
      }
      return;
    }
    if (ok) {
      AppFeedback.success(context, 'Senha alterada com sucesso!');
    } else {
      AppFeedback.error(context, vm.erro!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecuperacaoViewModel>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: ResponsiveBody(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: vm.etapa == EtapaRecuperacao.email
              ? Form(
                  key: _emailForm,
                  child: Column(
                    key: const ValueKey('etapa-email'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset, size: 64),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Informe o e-mail da sua conta. Vamos enviar um código para você criar uma nova senha.',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CeiTextField(
                        controller: _email,
                        label: 'E-mail',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.send,
                        validator: Validators.email,
                        onFieldSubmitted: (_) => _enviar(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CeiButton(
                        label: 'Enviar código',
                        icon: Icons.send_outlined,
                        isLoading: vm.carregando,
                        onPressed: _enviar,
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _codigoForm,
                  child: Column(
                    key: const ValueKey('etapa-codigo'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Digite o código enviado para ${vm.email} e escolha a nova senha.',
                        style: textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CeiTextField(
                        controller: _codigo,
                        label: 'Código',
                        prefixIcon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        validator: Validators.otpCode,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CeiTextField(
                        controller: _senha,
                        label: 'Nova senha',
                        helper: 'Mínimo de 8 caracteres, com letras e números',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        validator: Validators.strongPassword,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CeiTextField(
                        controller: _confirmar,
                        label: 'Confirmar nova senha',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        validator: Validators.confirmPassword(() => _senha.text),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CeiButton(
                        label: 'Salvar nova senha',
                        icon: Icons.check,
                        isLoading: vm.carregando,
                        onPressed: _redefinir,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      CeiButton(
                        label: 'Usar outro e-mail / reenviar',
                        variant: CeiButtonVariant.text,
                        onPressed: vm.carregando ? null : vm.voltarParaEmail,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
