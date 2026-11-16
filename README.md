# CEI Mobile — Controle de Estoque Inteligente

> Aplicativo móvel do Projeto Integrador **"CEI - Controle de Estoque Inteligente"**.
> Centro Universitário SENAI/SC — Campus Jaraguá do Sul · CST em Análise e Desenvolvimento de Sistemas · UC Desenvolvimento de Sistemas Móveis.

## Descrição e escopo

O CEI é uma plataforma de gestão de estoque para **micro e pequenas empresas** que ainda controlam produtos em cadernos ou planilhas. O app leva para o celular os fluxos do dia a dia do balcão e do depósito:

- **Dashboard** com faturamento do dia (e variação em relação a ontem), itens em estoque, itens críticos, alertas de validade e **recomendações automáticas** (repor, aplicar desconto, aumentar pedido);
- **Estoque** com busca em tempo real, filtros, barra visual de nível (verde/amarelo/vermelho), badges OK / Atenção / Baixo / Crítico, **alertas de validade (30, 15 e 5 dias)** e **sugestão automática de desconto** para itens com menos de 7 dias;
- **Entradas, saídas e ajustes** de estoque com histórico completo por produto;
- **Leitura de código de barras** pela câmera, com preenchimento automático via **Open Food Facts**;
- **Minhas Vendas**: registro de vendas, histórico pessoal, **ticket médio** e filtro por período;
- **Equipe e turnos** (gerente): cargos, turnos, situação (Ativo/Férias/Afastado) e bloqueio de acesso;
- **Assistente CEI**: chat que responde "O que está faltando?", "O que vence essa semana?", "Sugerir desconto", "Resumo de vendas", "O que devo comprar?" com os **dados reais** da empresa;
- **Funcionamento offline**: consulta do estoque salvo no aparelho e fila de vendas/movimentações enviadas automaticamente quando a internet volta.

### Perfis de usuário (RBAC)

| Perfil | Dashboard | Estoque (consulta) | Cadastro / movimentação | Excluir produto | Vendas | Vendas de todos | Equipe |
|---|---|---|---|---|---|---|---|
| Gerente | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vendedor | ✅ | ✅ | — | — | ✅ (próprias) | — | — |
| Caixa | ✅ | ✅ | — | — | ✅ (próprias) | — | — |
| Estoquista | ✅ | ✅ | ✅ | — | — | — | — |

As permissões são aplicadas **na interface** (menus e rotas protegidas) **e no banco** (Row Level Security + funções SQL), então manipular o app não dá acesso a nada.

### Fora do mobile (justificativa)

- **WhatsApp Business e IA generativa**: ficam no backend do PI (Golang), pois exigem a API oficial da Meta e processamento no servidor. No app, o Assistente responde com regras sobre os dados reais.
- **Importação de planilhas Excel e relatórios analíticos**: ficam no painel web (React), que é mais adequado para telas grandes.
- **Offline**: o documento do PI define que o sistema exige internet; no app implementamos um modo offline **parcial** (consulta + fila de operações), exigido pela UC, sem afetar a regra do PI de que o servidor é a fonte da verdade.

## Integrantes e Papéis

| Nome | GitHub | Papel | Responsabilidades técnicas |
|---|---|---|---|
| João Vitor da Silva | [@JoaooVitorSilva](https://github.com/JoaooVitorSilva) | Tech Lead / Arquiteto | Estrutura MVVM, revisão de PRs, integração com o Supabase |
| João Volkmann | [@JoaoVolkmann](https://github.com/JoaoVolkmann) | UI/UX & Design System | Tema, tokens, biblioteca de componentes, acessibilidade |
| Andrey Adrian Lazorotto | [@andreyLazarotto](https://github.com/andreyLazarotto) | Dados & Persistência | Modelos/DTOs, sqflite, offline/sincronização, repositórios |
| Isaac de Lima Fonseca | _@usuario_ | Backend & Integrações / QA | RLS e RPCs do Supabase, APIs externas, testes, PROMPT_LOG |

> Todos os integrantes codificam; os papéis indicam liderança de área.

## Stack, Backend e Pacotes

- **Flutter** (canal stable) / **Dart 3.9+**
- **Backend:** Supabase — Auth, PostgreSQL com **Row Level Security**, funções RPC transacionais
- **Pacotes:** `supabase_flutter`, `go_router`, `provider`, `sqflite` (+ `sqflite_common_ffi_web` para rodar no navegador), `flutter_secure_storage`, `shared_preferences`, `dio`, `connectivity_plus`, `mobile_scanner`, `intl`
- **APIs REST externas:** [BrasilAPI](https://brasilapi.com.br) (dados da empresa pelo CNPJ) e [Open Food Facts](https://world.openfoodfacts.org) (produto pelo código de barras)

## Arquitetura

Padrão **MVVM** com repositórios (offline-first):

```
View (features/*/views)          ← só desenha e repassa eventos
   │ context.watch / read
ViewModel (features/*/viewmodels) ← estado da tela + regras de apresentação (ChangeNotifier)
   │
Repository (data/repositories)   ← decide entre remoto e local, mapeia erros, fila offline
   │                    │
Remote (data/remote)   Local (data/local)
Supabase / Dio         sqflite (Singleton) · secure storage · shared_preferences
```

```
lib/
├── main.dart                 # inicialização e injeção de dependências (Provider)
├── app.dart                  # MaterialApp.router, temas, localização pt-BR
├── core/
│   ├── config/               # chaves via --dart-define-from-file (nada no código)
│   ├── errors/               # AppException + ErrorMapper (erro técnico → mensagem amigável)
│   ├── network/              # Dio com retry/log, ConnectivityService
│   ├── router/               # rotas centralizadas, guards de login e de cargo
│   ├── theme/                # tokens, AppTheme claro/escuro, ThemeExtension de status
│   └── utils/                # validadores, máscaras, debounce, gerador de UUID
├── data/
│   ├── models/               # DTOs (fromJson/toJson e fromMap/toMap)
│   ├── local/                # DatabaseHelper (Singleton + migrações), datasources locais
│   ├── remote/               # Supabase e APIs REST
│   └── repositories/         # orquestram remoto + local, SyncService, AssistenteService
├── features/                 # auth, dashboard, estoque, vendas, equipe, assistente, perfil, settings
└── shared/
    ├── viewmodels/           # PaginatedViewModel (base de listas paginadas)
    └── widgets/              # biblioteca de componentes (20+)
supabase/schema.sql           # tabelas, RLS, triggers e RPCs
```

### Estratégia offline e sincronização

1. Toda leitura vai ao Supabase e **atualiza o cache local** (sqflite).
2. Sem conexão, as listas usam o cache e a tela avisa ("Exibindo dados salvos no aparelho").
3. Vendas e movimentações feitas offline entram na tabela `operacoes_pendentes` com um **UUID gerado no app**.
4. Quando a conexão volta, o `SyncService` envia a fila. As funções SQL ignoram IDs já processados (**idempotência**: reenviar não duplica).
5. **Conflitos:** o servidor é a fonte da verdade. Se outro aparelho vendeu antes e o estoque acabou, a operação é rejeitada e fica marcada com o motivo para o usuário revisar ou descartar.
6. O perfil do usuário fica em cache para o app abrir sem internet. No logout, o banco local é apagado (LGPD).

## Segurança e Controle de Acesso

- **Autenticação:** Supabase Auth (cadastro, login, recuperação de senha por código, troca de senha, logout).
- **Sessão:** tokens guardados no **flutter_secure_storage** (Keystore/Keychain), não no SharedPreferences.
- **Multiempresa:** toda tabela tem `empresa_id` e o **RLS** só libera linhas da empresa do usuário (`minha_empresa()`).
- **Cargos:** políticas e RPCs checam `meu_cargo()`. Exemplos: só gerente/estoquista inserem produtos; só gerente arquiva produtos e edita a equipe; vendedor e caixa veem **apenas as próprias vendas**.
- **Integridade:** a quantidade em estoque só muda pelas RPCs `registrar_venda` / `registrar_movimentacao` (trigger bloqueia `UPDATE` direto), com `SELECT ... FOR UPDATE` para evitar venda acima do estoque.
- **Segredos:** `.env` fora do Git; o app só usa a chave pública (publishable/anon), protegida pelo RLS.

## Mapa de Telas

| # | Tela | Perfil |
|---|---|---|
| 1 | Splash | Todos |
| 2 | Login | Todos |
| 3 | Cadastro (criar empresa ou entrar com código) | Todos |
| 4 | Recuperação de senha (código por e-mail) | Todos |
| 5 | Dashboard | Todos |
| 6 | Estoque (busca, filtros, paginação) | Todos |
| 7 | Detalhe do produto + histórico | Todos |
| 8 | Cadastro/edição de produto | Gerente, Estoquista |
| 9 | Movimentação (entrada/saída/ajuste) | Gerente, Estoquista |
| 10 | Alertas de validade | Todos |
| 11 | Leitor de código de barras | Todos |
| 12 | Minhas Vendas | Gerente, Vendedor, Caixa |
| 13 | Nova venda | Gerente, Vendedor, Caixa |
| 14 | Equipe e turnos | Gerente |
| 15 | Editar funcionário | Gerente |
| 16 | Assistente CEI | Todos |
| 17 | Meu perfil | Todos |
| 18 | Alterar senha | Todos |
| 19 | Configurações | Todos |
| 20 | Operações pendentes (offline) | Todos |
| 21 | Acesso negado | Todos |

## Matriz de Requisitos

| ID | Requisito | Status | Onde está |
|---|---|---|---|
| C1.1 | Design System centralizado | ✅ | `lib/core/theme/` |
| C1.2 | Claro/Escuro/Sistema persistido | ✅ | `features/settings/viewmodels/theme_viewmodel.dart` |
| C1.3 | ≥ 10 componentes reutilizáveis | ✅ (20+) | `lib/shared/widgets/` |
| C1.4 | Responsividade (360x640, paisagem, fonte ampliada) | ✅ | `ResponsiveBody`, `LayoutBuilder`, `HomeShell` (NavigationRail ≥ 840 px) |
| C1.5 | Acessibilidade | ✅ | `Semantics`, `tooltip` em ícones, alvos ≥ 48 dp, teste com fonte 1.3x |
| C1.6 | Feedback consistente | ✅ | `AppFeedback`, `state_views.dart`, `ErrorMapper` |
| C1.7 | Experiência refinada | 🟡 | Hero, AnimatedSwitcher, pull-to-refresh |
| C2.1 | ≥ 10 telas | ✅ (21) | Mapa de telas |
| C2.2 | Rotas centralizadas + retorno de resultado | ✅ | `core/router/`, `context.push<Produto>()` |
| C2.3 | Parâmetros tipados | ✅ | `extra: Produto` / `extra: Perfil` |
| C2.4 | Autenticação completa | ✅ | `data/repositories/auth_repository.dart`, `features/auth/` |
| C2.5 | Rotas protegidas + perfil (UI e backend) | ✅ | `app_router.dart` (`_redirect`), `supabase/schema.sql` |
| C2.6 | Ciclo de vida (`dispose`, `mounted`) | ✅ | todas as telas com controllers |
| C2.7 | PopScope nos formulários | ✅ | `shared/widgets/unsaved_changes_guard.dart` |
| C2.8 | Validação + máscaras | ✅ | `core/utils/validators.dart`, `formatters.dart` |
| C2.9 | Estado desacoplado (MVVM) | ✅ | `features/*/viewmodels/` |
| C3.1/3.2 | Lazy loading em todas as coleções | ✅ | `ListView.builder/separated`, `SliverList`, `SliverGrid` |
| C3.3 | Paginação / scroll infinito | ✅ | `PaginatedViewModel`, `PagedListView` |
| C3.4 | Busca com debounce e filtros | ✅ | `ProdutosViewModel`, `Debouncer` |
| C4.1 | Banco local com CRUD | ✅ | `data/local/*_datasource.dart` |
| C4.2 | Singleton + migrações | ✅ | `data/local/database_helper.dart` (v1 → v2) |
| C4.3 | DTOs tipados | ✅ | `data/models/` |
| C4.4 | Offline definido + indicador | ✅ | repositórios, `ConnectivityBanner`, `PendenciasView` |
| C4.5 | Preferências + tokens seguros | ✅ | `preferences_service.dart`, `secure_session_storage.dart` |
| C4.6 | Confirmação + Desfazer | ✅ | `confirm_dialog.dart`, `Dismissible` + SnackBar "Desfazer" |
| C4.7 | Sincronização com conflitos | ✅ | `data/repositories/sync_service.dart` |
| C5.1 | Backend real | ✅ | Supabase |
| C5.2 | API REST externa | ✅ | `brasil_api_service.dart`, `open_food_facts_service.dart` |
| C5.3 | Aguardando / Erro / Sucesso / Vazio | ✅ | `state_views.dart` em todas as listas |
| C5.4 | Exceções tratadas | ✅ | `core/errors/error_mapper.dart` (rede, timeout, HTTP, JSON, auth, permissão) |
| C5.5 | Segurança | ✅ | RLS + `.env` fora do Git |
| C5.6 | Camada de serviços isolada | ✅ | `data/remote/` + repositórios |
| C5.7 | Interceptors | ✅ | `core/network/http_client.dart` (retry + log) |
| C5.8 | Recurso nativo | ✅ | câmera / código de barras (`scanner_view.dart`) |
| C6.1 | Arquitetura documentada | ✅ | esta seção |
| C6.2 | `flutter analyze` limpo | ✅ | `analysis_options.yaml` |
| C6.3 | Testes automatizados | ✅ | `test/` (modelos, regras, ViewModels, widget) |
| C6.4 | PROMPT_LOG | ✅ | `PROMPT_LOG.md` |
| C6.8 | Injeção de dependências + erros centralizados | ✅ | `main.dart`, `ErrorMapper` |
| C6.9 | CI | ✅ | `.github/workflows/ci.yml` |

## Como executar

Pré-requisitos: Flutter SDK (stable) e um projeto no Supabase.

```bash
git clone https://github.com/CEI-Controle-de-Estoque-Inteligente/cei-mobile.git
cd cei-mobile
flutter pub get
dart run scripts/configurar_nativo.dart     # permissões Android/iOS
```

1. No Supabase, abra **SQL Editor**, cole o conteúdo de `supabase/schema.sql` e clique em **Run**.
2. Em **Authentication > Email Templates > Reset Password**, inclua `{{ .Token }}` no corpo do e-mail (o app usa o código de 6 dígitos).
3. Copie `.env.example` para `.env` e preencha `SUPABASE_URL` e `SUPABASE_KEY` (Project Settings > API).
4. Rode:

```bash
flutter run --dart-define-from-file=.env              # celular/emulador
dart run sqflite_common_ffi_web:setup                 # só na 1ª vez, para rodar no navegador
flutter run -d chrome --dart-define-from-file=.env    # navegador
```

Qualidade:

```bash
flutter analyze
flutter test
```

APK:

```bash
flutter build apk --release --dart-define-from-file=.env
```

## Credenciais de teste (por perfil)

| Perfil | E-mail | Senha |
|---|---|---|
| Gerente | _preencher_ | _enviar ao professor em privado_ |
| Vendedor | _preencher_ | |
| Estoquista | _preencher_ | |

Para popular a empresa com produtos de exemplo: entre como gerente → Configurações → **Carregar dados de demonstração** (seed documentado em `supabase/schema.sql`, função `popular_demo`).

## Telas (Claro / Escuro)

<img width="1364" height="944" alt="Tela do CEI Mobile" src="https://github.com/user-attachments/assets/a2af289b-942c-40da-86b7-9d7cf8c37ddc" />

<img width="1364" height="943" alt="Tela do CEI Mobile" src="https://github.com/user-attachments/assets/29a07ec9-9c37-4a3e-99ab-210ca273c874" />

## Vídeo de demonstração

_Link na entrega final._

## Links

- Quadro Ágil: https://github.com/orgs/CEI-Controle-de-Estoque-Inteligente/projects/1
- APK: Releases (tag `v1.0`)
- [PROMPT_LOG.md](PROMPT_LOG.md)
