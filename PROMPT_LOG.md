# PROMPT_LOG — Governança de IA

Registro do uso de assistentes de IA no desenvolvimento do CEI Mobile, conforme a Seção 13 do enunciado.
Todo código gerado é revisado por um integrante antes do commit.

## Ferramentas utilizadas

| Ferramenta | Versão/Modelo | Finalidade |
|---|---|---|
| Claude | Claude Opus 5.5 | Estrutura inicial do projeto (Sprint 0), README, planejamento de issues |

## Registro de Prompts

### #01 — 26/10/2026 — João Vitor da Silva — Claude

- **Objetivo:** gerar a base da Sprint 0: estrutura MVVM, tema claro/escuro persistido, splash, login estruturado, README e lista de issues.
- **Prompt:** "Me ajude a fazer a entrega da Sprint 0 do app mobile do Projeto Integrador CEI (Flutter), seguindo o enunciado anexo: estrutura de pastas, tema global claro/escuro, tela de autenticação, README, PROMPT_LOG e quadro ágil."
- **Resultado:** Aceito com ajustes.
- **Arquivos afetados:** `lib/**`, `test/**`, `README.md`, `.gitignore`, `analysis_options.yaml`.
- **Observações críticas:**
  - Conferido que nenhum widget descontinuado foi usado (`WillPopScope`, `Color.withOpacity`, `RaisedButton`, `headline1`).
  - Conferido `dispose()` de `TextEditingController`, `FocusNode` e `Timer`, e `mounted` após `await`.
  - O `LoginViewModel` chamava `notifyListeners()` depois que o roteador já tinha descartado a tela: corrigido (Refatoração 1).
  - O seletor de tema estourava a largura em telas de 360 dp: corrigido (Refatoração 2).
  - A autenticação desta sprint é preliminar e está isolada atrás da interface `AuthRepository`, para troca pelo Supabase na Sprint 1.

## Refatorações Manuais Críticas

### Refatoração 1 — notifyListeners após dispose no login

- **Categoria:** Bug / Ciclo de vida
- **Código gerado (antes):**

```dart
} finally {
  _isLoading = false;
  notifyListeners();
}
```

- **Problema identificado:** após o login, o `SessionViewModel` notifica o `GoRouter`, que redireciona para a Home e descarta a tela de login (e seu `LoginViewModel`). O `finally` executa depois disso e chama `notifyListeners()` em um `ChangeNotifier` já descartado, gerando exceção em modo debug.
- **Código refatorado (depois):**

```dart
} finally {
  _isLoading = false;
  if (!_disposed) notifyListeners();
}

bool _disposed = false;

@override
void dispose() {
  _disposed = true;
  super.dispose();
}
```

- **Justificativa técnica:** a documentação de `ChangeNotifier` determina que o objeto não deve ser usado após `dispose()`. A flag garante que a notificação só ocorre enquanto há ouvintes válidos.
- **Commit:** _link_
- **Responsável:** _integrante_

### Refatoração 2 — overflow do seletor de tema em telas pequenas

- **Categoria:** Responsividade (C1.4)
- **Código gerado (antes):** `SegmentedButton` com ícone + texto fixos nos três segmentos.
- **Problema identificado:** em 360x640 com o padding da tela, os três segmentos rotulados não cabem na largura disponível e causam overflow.
- **Código refatorado (depois):**

```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final compact = constraints.maxWidth < _compactBreakpoint;
    return SegmentedButton<ThemeMode>(
      segments: [
        for (final (mode, icon, label) in _options)
          ButtonSegment(
            value: mode,
            icon: Icon(icon),
            label: compact ? null : Text(label),
            tooltip: 'Tema: $label',
          ),
      ],
      // ...
    );
  },
);
```

- **Justificativa técnica:** `LayoutBuilder` adapta o componente ao espaço real; em modo compacto o rótulo continua acessível via `tooltip`/semântica. Coberto pelo teste `login não estoura em tela pequena (360x640)`.
- **Commit:** _link_
- **Responsável:** _integrante_

## Lições aprendidas

_A preencher ao longo das sprints._
