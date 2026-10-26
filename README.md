# CEI Mobile — Controle de Estoque Inteligente

> Aplicativo móvel do Projeto Integrador **"CEI - Controle de Estoque Inteligente"**.
> Centro Universitário SENAI/SC — Campus Jaraguá do Sul · CST em Análise e Desenvolvimento de Sistemas · UC Desenvolvimento de Sistemas Móveis.

**Status:** Sprint 0 — Setup e Planejamento

## Descrição e escopo

O CEI é uma plataforma de gestão de estoque para **micro e pequenas empresas**, que ajuda o dono do negócio a controlar produtos, validades e vendas, com apoio de um assistente inteligente.

O **app mobile** leva para o celular os fluxos do dia a dia de quem está no balcão ou no depósito:

- Consulta e cadastro de produtos, com leitura de código de barras pela câmera;
- Entrada e saída de estoque (movimentações) e registro de vendas;
- Alertas de estoque baixo e de produtos próximos do vencimento;
- Dashboard com indicadores do dia;
- Assistente inteligente (chat) com resumos e sugestões;
- Funcionamento offline com sincronização ao reconectar.

**Perfis de usuário**

| Perfil | Acesso |
|---|---|
| Administrador (dono) | Tudo, incluindo gestão de funcionários, relatórios e configurações da empresa |
| Funcionário | Consulta de produtos, movimentações, vendas e alertas; sem gestão de usuários |

**Fora do mobile:** relatórios analíticos detalhados e configurações avançadas permanecem no painel web (React) do PI, por exigirem tela grande.

## Integrantes e Papéis

| Nome | GitHub | Papel | Responsabilidades técnicas |
|---|---|---|---|
| João Vitor da Silva | @JoaooVitorSilva | Tech Lead / Arquiteto | Estrutura do projeto, padrão MVVM, revisão de PRs |
| João Volkmann | @JoaoVolkmann | UI/UX & Design System | Tema, tokens, biblioteca de componentes, acessibilidade |
| Andrey Adrian Lazorotto | @andreyLazarotto | Dados & Persistência | Modelagem, sqflite, sincronização, repositórios |
| Isaac de Lima Fonseca | @USUARIO | Backend & Integrações / QA | Supabase (Auth, RLS), APIs externas, testes, PROMPT_LOG |

> Todos os integrantes codificam; os papéis indicam liderança de área.

## Stack, Backend e Pacotes

- **Flutter** (canal stable) / **Dart 3.9+**
- **Backend:** Supabase (Auth + PostgreSQL com Row Level Security + Storage)
- **Pacotes (Sprint 0):** `provider`, `go_router`, `shared_preferences`
- **Pacotes previstos:** `supabase_flutter`, `sqflite`, `flutter_secure_storage`, `dio`, `connectivity_plus`, `mobile_scanner`, `cached_network_image`

## Arquitetura

Padrão **MVVM** com separação em camadas:

```
View (features/*/views)  ──>  ViewModel (features/*/viewmodels, ChangeNotifier)
                                   │
                                   ▼
                       Repository (data/repositories)
                         │                    │
                         ▼                    ▼
                 Local (data/local)    Remote (data/remote)
                 sqflite / prefs        Supabase / APIs REST
```

```
lib/
├── main.dart                 # inicialização e providers
├── app.dart                  # MaterialApp.router, temas
├── core/
│   ├── theme/                # tokens (cores, espaçamentos, raios) e AppTheme claro/escuro
│   ├── router/               # rotas centralizadas e guard de autenticação
│   ├── errors/               # exceções de domínio
│   ├── network/              # cliente HTTP, conectividade
│   └── utils/                # validadores, máscaras, formatadores
├── data/
│   ├── models/               # DTOs (toMap/fromMap, toJson/fromJson)
│   ├── local/                # preferências, banco local (Singleton)
│   ├── remote/               # serviços Supabase / APIs
│   └── repositories/         # orquestram local + remoto (offline-first)
├── features/
│   ├── splash/  auth/  home/  settings/
│   └── ...                   # products, stock, sales, alerts, assistant, admin
└── shared/widgets/           # biblioteca de componentes (DRY)
```

**Estratégia offline (planejada):** cache-first no sqflite + fila de sincronização com `updated_at` para envio ao Supabase quando houver conexão.

## Segurança e Controle de Acesso

- Rotas internas protegidas por guard no `go_router` (usuário não autenticado vai para o login);
- Permissões por perfil aplicadas na interface **e** no banco via **RLS** do Supabase (cada empresa só enxerga seus próprios dados; apenas admin gerencia funcionários);
- Chaves em `.env` (não versionado) — ver `.env.example`.

## Mapa de Telas (planejado)

| # | Tela | Perfil | Sprint |
|---|---|---|---|
| 1 | Splash | Todos | 0 ✅ |
| 2 | Login | Todos | 0 ✅ (estrutura) |
| 3 | Cadastro de conta/empresa | Admin | 1 |
| 4 | Recuperação de senha | Todos | 1 |
| 5 | Dashboard (indicadores do dia) | Todos | 1 |
| 6 | Lista de produtos (busca, filtros, paginação) | Todos | 1 |
| 7 | Detalhe do produto | Todos | 1 |
| 8 | Formulário de produto | Admin | 1 |
| 9 | Movimentação de estoque (entrada/saída) | Todos | 1 |
| 10 | Leitor de código de barras | Todos | 2 |
| 11 | Alertas (estoque baixo / validade) | Todos | 2 |
| 12 | Vendas (lista + registrar venda) | Todos | 2 |
| 13 | Assistente inteligente (chat) | Todos | 2 |
| 14 | Perfil do usuário | Todos | 1 |
| 15 | Gestão de funcionários | Admin | 2 |
| 16 | Configurações (tema, conta) | Todos | 0 ✅ (tema) |

## Matriz de Requisitos

| ID | Requisito | Status | Onde está |
|---|---|---|---|
| C1.1 | Design System centralizado | 🟡 Iniciado | `lib/core/theme/` |
| C1.2 | Claro/Escuro persistido | ✅ | `features/settings/viewmodels/theme_viewmodel.dart` |
| C1.3 | ≥ 10 componentes reutilizáveis | 🟡 5/10 | `lib/shared/widgets/` |
| C2.2 | Rotas centralizadas | ✅ | `lib/core/router/` |
| C2.5 | Rotas protegidas | 🟡 Guard pronto, auth real na Sprint 1 | `app_router.dart` |
| C2.6 | dispose / mounted | ✅ nas telas existentes | `login_view.dart`, `splash_view.dart` |
| C2.8 | Validação de formulários | 🟡 Login | `core/utils/validators.dart` |
| C2.9 | Estado desacoplado (MVVM) | ✅ | `features/*/viewmodels/` |
| C4.5 | Preferências persistidas | ✅ tema | `data/local/preferences_service.dart` |
| C6.3 | Testes automatizados | 🟡 Iniciado | `test/` |

A matriz completa é acompanhada pelas issues do quadro ágil.

## Como executar

Pré-requisitos: Flutter SDK (stable) e um emulador ou dispositivo Android.

```bash
git clone https://github.com/CEI-Controle-de-Estoque-Inteligente/cei-mobile.git
cd cei-mobile
flutter pub get
flutter run
```

Qualidade:

```bash
flutter analyze
flutter test
```

A partir da Sprint 1 (Supabase): copie `.env.example` para `.env`, preencha as chaves e rode `flutter run --dart-define-from-file=.env`.

## Credenciais de teste (por perfil)

Serão publicadas na Sprint 1, após a integração com o Supabase Auth.
Na Sprint 0 o login é **preliminar** (valida o formulário e libera a navegação, sem backend).

## Telas (Claro / Escuro)

_Prints a adicionar._

## Vídeo de demonstração

_Link na entrega final._

## Links

- Quadro Ágil: _link do GitHub Projects_
- APK: _Releases (entrega final)_
- Protótipo: _link do Figma_
- [PROMPT_LOG.md](PROMPT_LOG.md)
