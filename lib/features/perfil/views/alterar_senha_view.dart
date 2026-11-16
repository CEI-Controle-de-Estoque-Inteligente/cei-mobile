import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/cei_button.dart';
import '../../../shared/widgets/cei_text_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/perfil_viewmodel.dart';

class AlterarSenhaView extends StatelessWidget {
  const AlterarSenhaView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => PerfilViewModel(context.read<AuthRepository>(), context.read<SessionViewModel>()),
      child: const _AlterarSenhaForm(),
    );
  }
}

class _AlterarSenhaForm extends StatefulWidget {
  const _AlterarSenhaForm();

  @override
  State<_AlterarSenhaForm> createState() => _AlterarSenhaFormState();
}

class _AlterarSenhaFormState extends State<_AlterarSenhaForm> {
  final _formKey = GlobalKey<FormState>();
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmar = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _atual.dispose();
    _nova.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vm = context.read<PerfilViewModel>();
    final ok = await vm.alterarSenha(atual: _atual.text, nova: _nova.text);
    if (!mounted) return;
    if (!ok) {
      AppFeedback.error(context, vm.erro!);
      return;
    }
    setState(() => _dirty = false);
    AppFeedback.success(context, 'Senha alterada com sucesso.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PerfilViewModel>();
    return UnsavedChangesGuard(
      hasChanges: _dirty && !vm.salvando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Alterar senha')),
        body: ResponsiveBody(
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CeiTextField(
                  controller: _atual,
                  label: 'Senha atual',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _nova,
                  label: 'Nova senha',
                  helper: 'Mínimo de 8 caracteres, com letras e números',
                  prefixIcon: Icons.lock_reset,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.strongPassword,
                ),
                const SizedBox(height: AppSpacing.md),
                CeiTextField(
                  controller: _confirmar,
                  label: 'Confirmar nova senha',
                  prefixIcon: Icons.lock_reset,
                  obscureText: true,
                  validator: Validators.confirmPassword(() => _nova.text),
                ),
                const SizedBox(height: AppSpacing.lg),
                CeiButton(label: 'Salvar nova senha', icon: Icons.check, isLoading: vm.salvando, onPressed: _salvar),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
