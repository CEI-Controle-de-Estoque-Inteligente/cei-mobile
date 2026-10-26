#!/usr/bin/env bash
# =============================================================================
# Sprint 0 — cria labels, milestones, issues e o GitHub Project do CEI Mobile.
# Requisitos: GitHub CLI (gh) logado com escopo de projeto:
#   gh auth login
#   gh auth refresh -s project
# No Windows, rode pelo Git Bash:  bash scripts/setup_quadro.sh
# =============================================================================
set -euo pipefail

# ---- PREENCHA AQUI ----------------------------------------------------------
ORG="CEI-Controle-de-Estoque-Inteligente"
REPO="cei-mobile"
DEV1="usuario_joao"     # Tech Lead / Arquiteto
DEV2="usuario_2"        # UI/UX & Design System
DEV3="usuario_3"        # Dados & Persistência
DEV4="usuario_4"        # Backend & Integrações / QA
# -----------------------------------------------------------------------------

R="$ORG/$REPO"
S0="Sprint 0 - Setup"
S1="Sprint 1 - Fundação e Dados"
S2="Sprint 2 - Conectividade"
S3="Sprint 3 - Qualidade e Governança"

echo ">> Labels"
lbl() { gh label create "$1" --repo "$R" --color "$2" --description "$3" --force >/dev/null; }
lbl "C1" "1d76db" "Interface, Design System e UX"
lbl "C2" "5319e7" "Navegação, autenticação e ciclo de vida"
lbl "C3" "fbca04" "Performance"
lbl "C4" "0e8a16" "Persistência local e offline"
lbl "C5" "d93f0b" "Backend, APIs e estados assíncronos"
lbl "C6" "6f42c1" "Engenharia, qualidade e governança de IA"
lbl "obrigatório" "b60205" "Requisito OBR"
lbl "desejável" "fef2c0" "Requisito DES"
lbl "opcional" "c2e0c6" "Requisito OPC"
lbl "tela" "0052cc" "Tela do app"
lbl "setup" "bfdadc" "Configuração do projeto"

echo ">> Milestones"
ms() {
  gh api "repos/$R/milestones" -f title="$1" -f description="$2" >/dev/null 2>&1 \
    || echo "   (milestone '$1' já existe)"
}
ms "$S0" "Kickoff, repositório, Design System inicial, autenticação estruturada, quadro ágil"
ms "$S1" "Auth completa, controle de acesso, modelos/DTO, banco local, CRUDs, formulários protegidos (Checkpoint aula 13)"
ms "$S2" "APIs REST, estados assíncronos, offline/sincronização, paginação, recursos nativos"
ms "$S3" "Refatoração, testes, acessibilidade, polimento, PROMPT_LOG e README"

echo ">> Issues"
# formato: milestone | labels | assignee | título | corpo
issue() {
  gh issue create --repo "$R" --milestone "$1" --label "$2" --assignee "$3" \
    --title "$4" --body "$5" >/dev/null
  echo "   + $4"
}

# ---------------- Sprint 0 ----------------
issue "$S0" "setup,C6,obrigatório" "$DEV1" "[C6.1] Estrutura MVVM e pastas do projeto" "Criar estrutura core/data/features/shared conforme Anexo C e documentar no README."
issue "$S0" "setup,C1,obrigatório" "$DEV2" "[C1.1] Tokens do Design System (cores, tipografia, espaçamentos, raios)" "app_tokens.dart + app_theme.dart com ThemeExtension de status de estoque."
issue "$S0" "setup,C1,obrigatório" "$DEV2" "[C1.2] Tema Claro/Escuro/Sistema persistido" "ThemeViewModel + shared_preferences; seletor no login e configurações."
issue "$S0" "tela,C2,obrigatório" "$DEV1" "[C2.1] Telas Splash e Login (estrutura)" "Splash com timer liberado no dispose; login com Form, validação e estados de carregamento."
issue "$S0" "setup,C6,obrigatório" "$DEV4" "[C6.7] README inicial e PROMPT_LOG.md" "README conforme Anexo A; PROMPT_LOG conforme Anexo B."
issue "$S0" "setup,C5,obrigatório" "$DEV4" "[C5.1] Criar projeto Supabase e documentar backend" "Projeto Supabase criado, .env.example, chaves fora do repositório."
issue "$S0" "setup,C6,obrigatório" "$DEV3" "[C6.6] Quadro ágil, milestones e issues" "Colunas Backlog/To Do/In Progress/Review/Done, milestones 0-3, labels e responsáveis."

# ---------------- Sprint 1 ----------------
issue "$S1" "C2,obrigatório" "$DEV4" "[C2.4] Autenticação real com Supabase Auth" "Login, cadastro, recuperação de senha, sessão persistida, logout e tratamento de erros (credencial inválida, e-mail já cadastrado)."
issue "$S1" "tela,C2,obrigatório" "$DEV1" "[C2.1] Tela de cadastro de conta/empresa" "Formulário com validação, máscara de CNPJ/telefone e PopScope."
issue "$S1" "tela,C2,obrigatório" "$DEV1" "[C2.1] Tela de recuperação de senha" "Envio de e-mail de redefinição pelo Supabase com feedback de sucesso/erro."
issue "$S1" "C2,C5,obrigatório" "$DEV4" "[C2.5] Controle de acesso por perfil (admin/funcionário) na UI e RLS" "Guards no go_router por perfil + políticas RLS no Supabase por empresa e perfil."
issue "$S1" "C4,obrigatório" "$DEV3" "[C4.1][C4.2] DatabaseHelper Singleton com sqflite e migrações" "onCreate/onUpgrade versionados; CRUD persistente após fechar o app."
issue "$S1" "C4,obrigatório" "$DEV3" "[C4.3] Models/DTOs Produto, Movimentação, Venda, Usuário" "toMap/fromMap e toJson/fromJson com nulos, datas e enums tratados."
issue "$S1" "C4,obrigatório" "$DEV4" "[C4.5] Tokens de sessão em flutter_secure_storage" "Sessão do Supabase armazenada de forma segura."
issue "$S1" "tela,C2,obrigatório" "$DEV2" "[C2.1] Dashboard com indicadores do dia" "Cards de estoque total, itens críticos, vencendo e vendas do dia."
issue "$S1" "tela,C3,obrigatório" "$DEV3" "[C2.1][C3.1] Lista de produtos com ListView.builder" "Lazy loading, estados vazio/erro/carregando."
issue "$S1" "tela,C2,obrigatório" "$DEV3" "[C2.1][C2.3] Detalhe do produto com parâmetro tipado" "Recebe objeto Produto pelo extra tipado do go_router."
issue "$S1" "tela,C2,obrigatório" "$DEV1" "[C2.7][C2.8] Formulário de produto com PopScope e validação" "Criar/editar produto; confirmação ao sair com alterações."
issue "$S1" "tela,C2,obrigatório" "$DEV2" "[C2.1] Tela de movimentação de estoque (entrada/saída)" "Regras: saída não pode deixar estoque negativo; histórico registrado."
issue "$S1" "tela,C2,obrigatório" "$DEV2" "[C2.1] Perfil do usuário (editar dados e trocar senha)" "Persistência das alterações no Supabase."
issue "$S1" "C1,obrigatório" "$DEV2" "[C1.3] Biblioteca com ≥ 10 componentes reutilizáveis" "Botão, campo, card de produto, app bar, estados vazio/erro/carregando, diálogo de confirmação, badge de status, chip, avatar, bottom sheet."
issue "$S1" "C4,obrigatório" "$DEV3" "[C4.6] Confirmação e desfazer em exclusões" "Dismissible + confirmDismiss e SnackBar com Desfazer."
issue "$S1" "C2,obrigatório" "$DEV1" "[C2.9] ViewModels sem regra de negócio nas telas" "Revisar todas as telas: acesso a dados apenas via repositórios."

# ---------------- Sprint 2 ----------------
issue "$S2" "C5,obrigatório" "$DEV4" "[C5.2] Consumo de API REST externa (BrasilAPI CNPJ / Open Food Facts)" "Preencher dados da empresa pelo CNPJ e produto pelo código de barras, com dio e timeout."
issue "$S2" "C5,obrigatório" "$DEV4" "[C5.3][C5.4] Estados Aguardando/Erro/Sucesso e tratamento de exceções" "Sem internet, timeout, HTTP de erro e JSON inválido nunca quebram o app; botão Tentar novamente."
issue "$S2" "C5,obrigatório" "$DEV4" "[C5.6] Camada de serviços isolada (data/remote)" "UI nunca chama Supabase/HTTP diretamente."
issue "$S2" "C4,obrigatório" "$DEV3" "[C4.4] Modo offline com cache-first e indicador de conexão" "Consulta de dados locais e registro de movimentações para envio posterior."
issue "$S2" "C4,desejável" "$DEV3" "[C4.7] Sincronização bidirecional com updated_at" "Fila de sincronização e resolução de conflitos documentada."
issue "$S2" "C3,obrigatório" "$DEV1" "[C3.3][C3.4] Paginação infinita, busca com debounce e filtros" "Produtos e vendas com range/limit do Supabase."
issue "$S2" "tela,C5,opcional" "$DEV2" "[C5.8] Leitor de código de barras (mobile_scanner)" "Busca/cadastro de produto a partir do código lido."
issue "$S2" "tela,C2,obrigatório" "$DEV2" "[C2.1] Tela de alertas (estoque baixo e validade)" "Lista com status por cor (ThemeExtension) e ordenação por urgência."
issue "$S2" "tela,C2,obrigatório" "$DEV3" "[C2.1] Vendas: lista e registro de venda" "Venda baixa estoque automaticamente; histórico por período."
issue "$S2" "tela,C5,obrigatório" "$DEV4" "[C2.1] Assistente inteligente (chat)" "Integração com o assistente do PI; estados de carregamento e erro."
issue "$S2" "tela,C2,obrigatório" "$DEV1" "[C2.1] Gestão de funcionários (admin)" "Listar, convidar, ativar/desativar e atribuir perfil."
issue "$S2" "C5,desejável" "$DEV4" "[C5.7] Upload de foto do produto (Supabase Storage)" "image_picker + storage com políticas de acesso."

# ---------------- Sprint 3 ----------------
issue "$S3" "C1,obrigatório" "$DEV2" "[C1.4][C1.5] Revisão de responsividade e acessibilidade" "360x640, paisagem, teclado aberto, fonte 1.3x, contraste e alvos ≥ 48dp."
issue "$S3" "C1,desejável" "$DEV2" "[C1.7] Splash nativo, ícone, onboarding e microinterações" "flutter_native_splash, flutter_launcher_icons, skeleton loading."
issue "$S3" "C6,obrigatório" "$DEV4" "[C6.3] Testes de regras de negócio, DTOs e widget tests" "Cobrir validadores, movimentação de estoque, models e fluxo de login."
issue "$S3" "C6,obrigatório" "$DEV1" "[C6.2] flutter analyze sem erros e warnings" "Remover código morto e duplicação."
issue "$S3" "C6,desejável" "$DEV1" "[C6.9] CI com GitHub Actions (analyze + test)" "Workflow em cada PR com relatório de cobertura."
issue "$S3" "C6,obrigatório" "$DEV4" "[C6.4] Consolidar PROMPT_LOG.md" "Refatorações antes/depois com links de commit e lições aprendidas."
issue "$S3" "C6,obrigatório" "$DEV1" "[C6.7] README final, prints Claro/Escuro e vídeo" "Credenciais de teste por perfil e matriz de requisitos completa."
issue "$S3" "C6,opcional" "$DEV3" "[C6.10] APK release em Releases + tag v1.0" "Build release assinado."

echo ">> GitHub Project"
PROJ_NUM=$(gh project create --owner "$ORG" --title "CEI Mobile - Quadro Ágil" --format json --jq '.number')
gh project link "$PROJ_NUM" --owner "$ORG" --repo "$R"
for url in $(gh issue list --repo "$R" --state open --limit 200 --json url --jq '.[].url'); do
  gh project item-add "$PROJ_NUM" --owner "$ORG" --url "$url" >/dev/null
done

echo
echo "Pronto! Projeto: https://github.com/orgs/$ORG/projects/$PROJ_NUM"
echo "Falta 1 passo manual (2 min): no projeto, edite o campo Status para ter"
echo "Backlog, To Do, In Progress, Review e Done e mude a visualização para Board."
