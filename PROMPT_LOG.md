# PROMPT_LOG — Governança de IA

Registro do uso de assistentes de IA no desenvolvimento do CEI Mobile, conforme a Seção 13 do enunciado.
Todo código gerado é revisado por um integrante antes do commit.

## Ferramentas utilizadas

| Ferramenta | Versão/Modelo | Finalidade |
|---|---|---|
| Claude | Claude Opus 5.5 | Estrutura do projeto, schema Supabase, telas e ViewModels, testes, README |

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

### #02 — 26/10/2026 — João Vitor da Silva — Claude

- **Objetivo:** implementar os módulos do PI no app (autenticação Supabase, RBAC, dashboard, estoque, vendas, equipe, assistente, offline) a partir dos documentos de requisitos do PI.
- **Prompt:** "Agora precisamos finalizar o projeto. A documentação do PI está no contexto (requisitos de negócio, funcionais e especificação). Monte o app completo seguindo o enunciado da UC."
- **Resultado:** Aceito com ajustes (refatorações 3 a 7).
- **Arquivos afetados:** `lib/**`, `test/**`, `supabase/schema.sql`, `.github/workflows/ci.yml`.
- **Observações críticas:**
  - O schema SQL foi validado num PostgreSQL local antes do uso: cadastro com código inválido, vendedor tentando inserir produto, estoquista tentando vender, venda acima do estoque, envio duplicado da mesma venda e isolamento entre duas empresas.
  - A primeira versão controlava permissões só na interface; o enunciado exige backend. Foram criadas políticas RLS, funções `minha_empresa()`/`meu_cargo()` e trigger que impede alterar a quantidade fora das RPCs.
  - O documento do PI diz que o sistema não funciona offline, mas a UC exige (C4.4). Decisão: offline parcial (consulta + fila), com o servidor como fonte da verdade — registrado no README.

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

### Refatoração 3 — botões com largura infinita quebravam diálogos

- **Categoria:** Bug / Layout
- **Código gerado (antes):**

```dart
filledButtonTheme: FilledButtonThemeData(
  style: FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
  ),
),
```

- **Problema identificado:** `Size.fromHeight` define largura mínima **infinita**. Qualquer `FilledButton` dentro de uma `Row` ou nas ações de um `AlertDialog` gera o erro "BoxConstraints forces an infinite width".
- **Código refatorado (depois):**

```dart
minimumSize: const Size(64, AppSizes.minTouchTarget), // tema: altura de 48 dp

// CeiButton decide quando ocupar a largura toda:
child: expand ? SizedBox(width: double.infinity, child: button) : button,
```

- **Justificativa técnica:** o tema garante o alvo de toque de 48 dp (acessibilidade) sem impor largura; a largura total passa a ser uma opção explícita do componente.
- **Commit:** _link_
- **Responsável:** _integrante_

### Refatoração 4 — cards do dashboard estouravam com fonte ampliada

- **Categoria:** Responsividade / Acessibilidade (C1.4, C1.5)
- **Código gerado (antes):**

```dart
gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 260,
  mainAxisExtent: 148,
),
```

- **Problema identificado:** altura fixa de 148 px. Com a fonte do sistema em 1,3x, o texto do card não cabe e aparece a faixa amarela de overflow.
- **Código refatorado (depois):**

```dart
gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 260,
  mainAxisExtent: 150 * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.2).toDouble(),
),
```

- **Justificativa técnica:** a altura acompanha o `TextScaler` do sistema, respeitando a preferência de acessibilidade do usuário.
- **Commit:** _link_
- **Responsável:** _integrante_

### Refatoração 5 — respostas antigas sobrescrevendo a busca

- **Categoria:** Bug / Concorrência
- **Código gerado (antes):**

```dart
Future<void> recarregar() async {
  _carregando = true;
  final pagina = await buscarPagina(0);
  _itens..clear()..addAll(pagina.itens);
}
```

- **Problema identificado:** digitando rápido na busca, a resposta de "arr" podia chegar **depois** da resposta de "arroz" e substituir a lista certa pela errada.
- **Código refatorado (depois):**

```dart
final req = ++_requisicao;
final pagina = await buscarPagina(0);
if (req != _requisicao) return; // resposta antiga: descarta
```

- **Justificativa técnica:** cada recarga recebe um número; só a mais recente pode alterar o estado. Somado ao `Debouncer`, evita consultas desnecessárias e resultados trocados.
- **Commit:** _link_
- **Responsável:** _integrante_

### Refatoração 6 — venda duplicada ao reenviar a fila offline

- **Categoria:** Arquitetura / Integridade de dados (C4.7)
- **Código gerado (antes):** a RPC `registrar_venda(p_produto, p_quantidade)` sempre inseria uma nova venda.
- **Problema identificado:** se a internet cair **depois** de o servidor gravar a venda, mas antes da resposta chegar, o app guarda a operação na fila e a envia de novo, baixando o estoque duas vezes.
- **Código refatorado (depois):**

```sql
create or replace function registrar_venda(p_id uuid, p_produto uuid, p_quantidade integer) ...
  select * into v_venda from vendas where id = p_id;
  if found then return v_venda; end if; -- já processada: não duplica
```

```dart
final vendaId = IdGenerator.uuidV4(); // gerado no app, reutilizado no reenvio
```

- **Justificativa técnica:** operação **idempotente**: o mesmo ID pode ser enviado várias vezes com o mesmo resultado. Testado no PostgreSQL local chamando a RPC duas vezes com o mesmo ID.
- **Commit:** _link_
- **Responsável:** _integrante_

### Refatoração 7 — APIs descontinuadas / quebras de versão

- **Categoria:** Legado/descontinuado
- **Problemas identificados e correções:**
  - `Supabase.initialize(anonKey: ...)` está marcado como `@Deprecated` na versão 2.18 → trocado por `publishableKey`.
  - `DropdownButtonFormField(value: ...)` está descontinuado → `initialValue`.
  - `switch` exaustivo em `DioExceptionType` quebraria quando o Dio adicionou `transformTimeout` (5.11) → uso de `default` para os casos genéricos.
- **Justificativa técnica:** o enunciado (Seção 13) penaliza APIs descontinuadas; as versões foram conferidas no código-fonte de cada pacote.
- **Commit:** _link_
- **Responsável:** _integrante_

## Lições aprendidas

- Código gerado por IA costuma "funcionar no caminho feliz": os problemas apareceram em fonte ampliada, telas pequenas, conexão instável e respostas fora de ordem. Testar esses cenários é obrigatório.
- Controle de acesso só na interface não é segurança. Toda regra de permissão foi duplicada no banco (RLS + RPCs).
- Testar o SQL num banco real antes de subir evitou erros que só apareceriam na demonstração.
- Conferir a versão atual de cada pacote evita usar APIs descontinuadas que a IA aprendeu em versões antigas.
