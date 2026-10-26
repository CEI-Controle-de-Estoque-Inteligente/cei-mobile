import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_logo.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/theme_mode_selector.dart';
import '../viewmodels/login_viewmodel.dart';
import '../viewmodels/session_viewmodel.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginViewModel(context.read<SessionViewModel>()),
      child: const _LoginForm(),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    // C2.6: controllers e FocusNode liberados
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final viewModel = context.read<LoginViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final success = await viewModel.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return; // C2.6: não usar context após await sem checar
    if (!success && viewModel.errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
    }
    // Em caso de sucesso, o guard do roteador redireciona para a Home.
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: ResponsiveBody(
        center: true,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CeiLogo(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Entre na sua conta',
                  style: textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                CeiTextField(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'voce@empresa.com.br',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  enabled: !viewModel.isLoading,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  label: 'Senha',
                  prefixIcon: Icons.lock_outline,
                  obscureText: viewModel.obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.password,
                  enabled: !viewModel.isLoading,
                  onFieldSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    tooltip: viewModel.obscurePassword
                        ? 'Mostrar senha'
                        : 'Ocultar senha',
                    icon: Icon(
                      viewModel.obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: viewModel.togglePasswordVisibility,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CeiButton(
                  label: 'Entrar',
                  icon: Icons.login,
                  isLoading: viewModel.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Cadastro e recuperação de senha: Sprint 1 (Supabase Auth)',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                const Center(child: ThemeModeSelector()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
