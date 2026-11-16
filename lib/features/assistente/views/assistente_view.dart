import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/perfil.dart';
import '../../../data/repositories/assistente_service.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/viewmodels/session_viewmodel.dart';
import '../viewmodels/assistente_viewmodel.dart';

/// Assistente CEI: chat com respostas baseadas nos dados reais da empresa.
class AssistenteView extends StatelessWidget {
  const AssistenteView({super.key});

  @override
  Widget build(BuildContext context) {
    final perfil = context.select<SessionViewModel, Perfil?>((s) => s.perfil);
    if (perfil == null) return const Scaffold(body: LoadingView());

    return ChangeNotifierProvider(
      create: (context) => AssistenteViewModel(context.read<AssistenteService>(), perfil),
      child: const _ChatBody(),
    );
  }
}

class _ChatBody extends StatefulWidget {
  const _ChatBody();

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _enviar(String texto) async {
    _input.clear();
    final vm = context.read<AssistenteViewModel>();
    final future = vm.enviar(texto);
    _rolarParaFim();
    await future;
    if (mounted) _rolarParaFim();
  }

  void _rolarParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssistenteViewModel>();
    final mensagens = vm.mensagens;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined),
            SizedBox(width: AppSpacing.sm),
            Text('Assistente CEI'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // reverse: as mensagens novas ficam embaixo, perto do teclado.
              child: ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: mensagens.length + (vm.respondendo ? 1 : 0),
                itemBuilder: (context, index) {
                  if (vm.respondendo && index == 0) {
                    return const _Bolha(texto: 'Consultando os dados...', doUsuario: false, digitando: true);
                  }
                  final i = mensagens.length - 1 - (index - (vm.respondendo ? 1 : 0));
                  final m = mensagens[i];
                  return _Bolha(
                    key: ValueKey(m.hora.microsecondsSinceEpoch),
                    texto: m.texto,
                    doUsuario: m.doUsuario,
                    hora: Formatters.time(m.hora),
                  );
                },
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: vm.sugestoes.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => ActionChip(
                  label: Text(vm.sugestoes[i]),
                  onPressed: vm.respondendo ? null : () => _enviar(vm.sugestoes[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      textInputAction: TextInputAction.send,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: _enviar,
                      decoration: const InputDecoration(hintText: 'Pergunte algo ao assistente'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: vm.respondendo ? null : () => _enviar(_input.text),
                    icon: Icon(Icons.send, color: colors.onPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  const _Bolha({super.key, required this.texto, required this.doUsuario, this.hora, this.digitando = false});

  final String texto;
  final bool doUsuario;
  final String? hora;
  final bool digitando;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fundo = doUsuario ? colors.primary : colors.surfaceContainerHighest;
    final cor = doUsuario ? colors.onPrimary : colors.onSurface;

    return Align(
      alignment: doUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(doUsuario ? AppRadius.lg : AppRadius.sm),
              bottomRight: Radius.circular(doUsuario ? AppRadius.sm : AppRadius.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (digitando)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cor)),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: Text(texto, style: TextStyle(color: cor))),
                  ],
                )
              else
                SelectableText(texto, style: TextStyle(color: cor)),
              if (hora != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(hora!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cor)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
