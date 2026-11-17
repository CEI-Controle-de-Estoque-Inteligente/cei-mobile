-- =============================================================================
-- CEI Mobile - Schema Supabase (PostgreSQL)
-- Rode este arquivo INTEIRO no Supabase: SQL Editor > New query > colar > Run.
-- É idempotente o suficiente para rodar em um projeto novo.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.cargo_t as enum ('gerente', 'vendedor', 'caixa', 'estoquista');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.turno_t as enum ('manha', 'tarde', 'integral');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_func_t as enum ('ativo', 'ferias', 'afastado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.mov_tipo_t as enum ('entrada', 'saida', 'ajuste', 'venda');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------
create table if not exists public.empresas (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(nome) between 2 and 120),
  cnpj text,
  codigo_convite text not null unique
    default upper(substr(md5(random()::text), 1, 6)),
  created_at timestamptz not null default now()
);

create table if not exists public.perfis (
  id uuid primary key references auth.users (id) on delete cascade,
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nome text not null check (char_length(nome) between 2 and 120),
  email text not null,
  cargo public.cargo_t not null default 'vendedor',
  turno public.turno_t not null default 'integral',
  status public.status_func_t not null default 'ativo',
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists perfis_empresa_idx on public.perfis (empresa_id);

create table if not exists public.produtos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  nome text not null check (char_length(nome) between 2 and 120),
  categoria text,
  codigo_barras text,
  preco numeric(12, 2) not null default 0 check (preco >= 0),
  quantidade integer not null default 0 check (quantidade >= 0),
  estoque_minimo integer not null default 0 check (estoque_minimo >= 0),
  estoque_maximo integer not null default 0 check (estoque_maximo >= 0),
  validade date,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status text generated always as (
    case
      when quantidade = 0 or quantidade <= estoque_minimo / 2 then 'critico'
      when quantidade <= estoque_minimo then 'baixo'
      when quantidade <= estoque_minimo * 1.5 then 'atencao'
      else 'ok'
    end
  ) stored
);
create index if not exists produtos_empresa_nome_idx
  on public.produtos (empresa_id, nome);
create index if not exists produtos_empresa_validade_idx
  on public.produtos (empresa_id, validade);
create unique index if not exists produtos_codigo_barras_uq
  on public.produtos (empresa_id, codigo_barras)
  where codigo_barras is not null and ativo;

create table if not exists public.movimentacoes (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  produto_id uuid not null references public.produtos (id) on delete cascade,
  usuario_id uuid references public.perfis (id) on delete set null,
  tipo public.mov_tipo_t not null,
  quantidade integer not null check (quantidade >= 0),
  saldo_apos integer not null,
  observacao text,
  created_at timestamptz not null default now()
);
create index if not exists movimentacoes_produto_idx
  on public.movimentacoes (produto_id, created_at desc);

create table if not exists public.vendas (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas (id) on delete cascade,
  operador_id uuid references public.perfis (id) on delete set null,
  produto_id uuid references public.produtos (id) on delete set null,
  produto_nome text not null,
  quantidade integer not null check (quantidade > 0),
  preco_unitario numeric(12, 2) not null,
  total numeric(12, 2) not null,
  created_at timestamptz not null default now()
);
create index if not exists vendas_empresa_data_idx
  on public.vendas (empresa_id, created_at desc);
create index if not exists vendas_operador_data_idx
  on public.vendas (operador_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Funções auxiliares de segurança (RBAC)
-- ---------------------------------------------------------------------------
create or replace function public.minha_empresa()
returns uuid language sql stable security definer set search_path = public as $$
  select empresa_id from perfis where id = auth.uid() and ativo;
$$;

create or replace function public.meu_cargo()
returns public.cargo_t language sql stable security definer set search_path = public as $$
  select cargo from perfis where id = auth.uid() and ativo;
$$;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create or replace function public.tg_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists perfis_updated_at on public.perfis;
create trigger perfis_updated_at before update on public.perfis
  for each row execute function public.tg_updated_at();

drop trigger if exists produtos_updated_at on public.produtos;
create trigger produtos_updated_at before update on public.produtos
  for each row execute function public.tg_updated_at();

-- Regras de produto aplicadas no banco (mesmo que alguém burle o app):
-- * quantidade só muda via movimentação (RPC);
-- * só o gerente arquiva/restaura (ativo).
create or replace function public.tg_produto_regras()
returns trigger language plpgsql as $$
begin
  if new.quantidade <> old.quantidade
     and coalesce(current_setting('cei.via_rpc', true), '') <> 'on' then
    raise exception 'A quantidade só pode ser alterada por uma movimentação de estoque.'
      using errcode = 'P0001';
  end if;
  if new.ativo <> old.ativo and public.meu_cargo() is distinct from 'gerente' then
    raise exception 'Apenas o gerente pode excluir ou restaurar produtos.'
      using errcode = '42501';
  end if;
  if new.empresa_id <> old.empresa_id then
    raise exception 'Não é permitido trocar a empresa do produto.' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists produtos_regras on public.produtos;
create trigger produtos_regras before update on public.produtos
  for each row execute function public.tg_produto_regras();

-- Estoque inicial vira movimentação de entrada (histórico completo).
create or replace function public.tg_produto_estoque_inicial()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.quantidade > 0 then
    insert into movimentacoes (empresa_id, produto_id, usuario_id, tipo, quantidade, saldo_apos, observacao)
    values (new.empresa_id, new.id, auth.uid(), 'entrada', new.quantidade, new.quantidade, 'Estoque inicial');
  end if;
  return new;
end $$;

drop trigger if exists produtos_estoque_inicial on public.produtos;
create trigger produtos_estoque_inicial after insert on public.produtos
  for each row execute function public.tg_produto_estoque_inicial();

-- Cadastro: cria a empresa (gerente) ou entra numa existente pelo código.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_codigo text := nullif(trim(new.raw_user_meta_data ->> 'codigo_empresa'), '');
  v_empresa uuid;
  v_cargo cargo_t;
begin
  if v_codigo is not null then
    select id into v_empresa from empresas where codigo_convite = upper(v_codigo);
    if v_empresa is null then
      raise exception 'Código de empresa inválido';
    end if;
    v_cargo := 'vendedor';
  else
    insert into empresas (nome, cnpj)
    values (
      coalesce(nullif(trim(new.raw_user_meta_data ->> 'empresa_nome'), ''), 'Minha empresa'),
      nullif(trim(new.raw_user_meta_data ->> 'cnpj'), '')
    )
    returning id into v_empresa;
    v_cargo := 'gerente';
  end if;

  insert into perfis (id, empresa_id, nome, email, cargo)
  values (
    new.id,
    v_empresa,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nome'), ''), split_part(new.email, '@', 1)),
    new.email,
    v_cargo
  );
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.empresas enable row level security;
alter table public.perfis enable row level security;
alter table public.produtos enable row level security;
alter table public.movimentacoes enable row level security;
alter table public.vendas enable row level security;

drop policy if exists empresas_select on public.empresas;
create policy empresas_select on public.empresas for select to authenticated
  using (id = public.minha_empresa());

drop policy if exists perfis_select on public.perfis;
create policy perfis_select on public.perfis for select to authenticated
  using (empresa_id = public.minha_empresa() or id = auth.uid());

-- Gerente edita a equipe, mas não a si mesmo (evita se rebaixar/desativar).
drop policy if exists perfis_update_gerente on public.perfis;
create policy perfis_update_gerente on public.perfis for update to authenticated
  using (empresa_id = public.minha_empresa() and public.meu_cargo() = 'gerente' and id <> auth.uid())
  with check (empresa_id = public.minha_empresa());

drop policy if exists produtos_select on public.produtos;
create policy produtos_select on public.produtos for select to authenticated
  using (empresa_id = public.minha_empresa());

drop policy if exists produtos_insert on public.produtos;
create policy produtos_insert on public.produtos for insert to authenticated
  with check (empresa_id = public.minha_empresa() and public.meu_cargo() in ('gerente', 'estoquista'));

drop policy if exists produtos_update on public.produtos;
create policy produtos_update on public.produtos for update to authenticated
  using (empresa_id = public.minha_empresa() and public.meu_cargo() in ('gerente', 'estoquista'))
  with check (empresa_id = public.minha_empresa());

drop policy if exists movimentacoes_select on public.movimentacoes;
create policy movimentacoes_select on public.movimentacoes for select to authenticated
  using (empresa_id = public.minha_empresa());

-- Cada operador vê só as próprias vendas; o gerente vê todas (RN001 - Vendas).
drop policy if exists vendas_select on public.vendas;
create policy vendas_select on public.vendas for select to authenticated
  using (empresa_id = public.minha_empresa()
         and (operador_id = auth.uid() or public.meu_cargo() = 'gerente'));

-- Inserções em movimentacoes/vendas só acontecem pelas RPCs abaixo.

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
create or replace function public.empresa_por_codigo(p_codigo text)
returns text language sql stable security definer set search_path = public as $$
  select nome from empresas where codigo_convite = upper(trim(p_codigo));
$$;
grant execute on function public.empresa_por_codigo(text) to anon, authenticated;

create or replace function public.atualizar_meu_nome(p_nome text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if char_length(trim(p_nome)) < 2 then
    raise exception 'Informe um nome válido.';
  end if;
  update perfis set nome = trim(p_nome) where id = auth.uid();
end $$;

-- p_id permite reenviar a mesma operação (fila offline) sem duplicar.
create or replace function public.registrar_movimentacao(
  p_id uuid,
  p_produto uuid,
  p_tipo public.mov_tipo_t,
  p_quantidade integer,
  p_observacao text default null
) returns public.produtos
language plpgsql security definer set search_path = public as $$
declare
  v_empresa uuid := minha_empresa();
  v_produto produtos;
  v_anterior integer;
  v_novo integer;
begin
  if v_empresa is null then
    raise exception 'Sessão inválida. Entre novamente.' using errcode = '42501';
  end if;
  if meu_cargo() not in ('gerente', 'estoquista') then
    raise exception 'Você não tem permissão para movimentar o estoque.' using errcode = '42501';
  end if;
  if exists (select 1 from movimentacoes where id = p_id) then
    select * into v_produto from produtos where id = p_produto;
    return v_produto;
  end if;
  if p_tipo not in ('entrada', 'saida', 'ajuste') then
    raise exception 'Tipo de movimentação inválido.';
  end if;
  if p_quantidade is null or p_quantidade < 0 or (p_tipo <> 'ajuste' and p_quantidade = 0) then
    raise exception 'Informe uma quantidade válida.';
  end if;

  select * into v_produto from produtos
   where id = p_produto and empresa_id = v_empresa and ativo
   for update;
  if not found then
    raise exception 'Produto não encontrado.';
  end if;

  v_anterior := v_produto.quantidade;
  v_novo := case p_tipo
    when 'entrada' then v_produto.quantidade + p_quantidade
    when 'saida' then v_produto.quantidade - p_quantidade
    else p_quantidade
  end;
  if v_novo < 0 then
    raise exception 'Estoque insuficiente: há apenas % unidade(s).', v_produto.quantidade;
  end if;

  perform set_config('cei.via_rpc', 'on', true);
  update produtos set quantidade = v_novo where id = p_produto returning * into v_produto;

  insert into movimentacoes (id, empresa_id, produto_id, usuario_id, tipo, quantidade, saldo_apos, observacao)
  values (p_id, v_empresa, p_produto, auth.uid(), p_tipo,
          case when p_tipo = 'ajuste' then abs(v_novo - v_anterior) else p_quantidade end,
          v_novo, nullif(trim(p_observacao), ''));
  return v_produto;
end $$;

create or replace function public.registrar_venda(
  p_id uuid,
  p_produto uuid,
  p_quantidade integer
) returns public.vendas
language plpgsql security definer set search_path = public as $$
declare
  v_empresa uuid := minha_empresa();
  v_produto produtos;
  v_venda vendas;
begin
  if v_empresa is null then
    raise exception 'Sessão inválida. Entre novamente.' using errcode = '42501';
  end if;
  if meu_cargo() not in ('gerente', 'vendedor', 'caixa') then
    raise exception 'Você não tem permissão para registrar vendas.' using errcode = '42501';
  end if;
  select * into v_venda from vendas where id = p_id;
  if found then
    return v_venda;
  end if;
  if p_quantidade is null or p_quantidade <= 0 then
    raise exception 'Informe uma quantidade válida.';
  end if;

  select * into v_produto from produtos
   where id = p_produto and empresa_id = v_empresa and ativo
   for update;
  if not found then
    raise exception 'Produto não encontrado.';
  end if;
  if v_produto.quantidade < p_quantidade then
    raise exception 'Estoque insuficiente: há apenas % unidade(s) de %.', v_produto.quantidade, v_produto.nome;
  end if;

  perform set_config('cei.via_rpc', 'on', true);
  update produtos set quantidade = quantidade - p_quantidade where id = p_produto;

  insert into movimentacoes (empresa_id, produto_id, usuario_id, tipo, quantidade, saldo_apos, observacao)
  values (v_empresa, p_produto, auth.uid(), 'venda', p_quantidade,
          v_produto.quantidade - p_quantidade, 'Venda');

  insert into vendas (id, empresa_id, operador_id, produto_id, produto_nome, quantidade, preco_unitario, total)
  values (p_id, v_empresa, auth.uid(), p_produto, v_produto.nome, p_quantidade,
          v_produto.preco, round(v_produto.preco * p_quantidade, 2))
  returning * into v_venda;
  return v_venda;
end $$;

-- Indicadores do dashboard (security invoker: respeita o RLS de vendas).
create or replace function public.dashboard_resumo()
returns json language sql stable set search_path = public as $$
  with hoje as (select (now() at time zone 'America/Sao_Paulo')::date as d)
  select json_build_object(
    'faturamento_hoje', coalesce((select sum(total) from vendas, hoje
        where (created_at at time zone 'America/Sao_Paulo')::date = hoje.d), 0),
    'faturamento_ontem', coalesce((select sum(total) from vendas, hoje
        where (created_at at time zone 'America/Sao_Paulo')::date = hoje.d - 1), 0),
    'vendas_hoje', (select count(*) from vendas, hoje
        where (created_at at time zone 'America/Sao_Paulo')::date = hoje.d),
    'produtos_ativos', (select count(*) from produtos where ativo),
    'itens_estoque', coalesce((select sum(quantidade) from produtos where ativo), 0),
    'itens_criticos', (select count(*) from produtos where ativo and status in ('critico', 'baixo')),
    'vencendo_15', (select count(*) from produtos, hoje
        where ativo and validade between hoje.d and hoje.d + 15),
    'vencidos', (select count(*) from produtos, hoje
        where ativo and validade < hoje.d and quantidade > 0)
  );
$$;

create or replace function public.resumo_vendas(
  p_inicio timestamptz,
  p_fim timestamptz,
  p_operador uuid default null
) returns json language sql stable set search_path = public as $$
  select json_build_object(
    'total', coalesce(sum(total), 0),
    'transacoes', count(*),
    'ticket_medio', coalesce(round(avg(total), 2), 0)
  )
  from vendas
  where created_at >= p_inicio and created_at < p_fim
    and (p_operador is null or operador_id = p_operador);
$$;

-- Giro dos produtos (base das recomendações de compra do Assistente).
create or replace function public.giro_produtos(p_dias integer default 30)
returns table (
  produto_id uuid,
  nome text,
  quantidade integer,
  estoque_minimo integer,
  vendido bigint,
  media_diaria numeric,
  dias_cobertura numeric
) language sql stable security definer set search_path = public as $$
  select p.id, p.nome, p.quantidade, p.estoque_minimo,
         coalesce(sum(v.quantidade), 0) as vendido,
         round(coalesce(sum(v.quantidade), 0)::numeric / greatest(p_dias, 1), 2) as media_diaria,
         case when coalesce(sum(v.quantidade), 0) = 0 then null
              else round(p.quantidade / (sum(v.quantidade)::numeric / greatest(p_dias, 1)), 1)
         end as dias_cobertura
    from produtos p
    left join vendas v on v.produto_id = p.id
                      and v.created_at >= now() - make_interval(days => p_dias)
   where p.empresa_id = minha_empresa() and p.ativo
   group by p.id
   order by dias_cobertura asc nulls last, vendido desc
   limit 50;
$$;

-- Seed de demonstração (documentado no README): só o gerente, só com estoque vazio.
create or replace function public.popular_demo()
returns integer language plpgsql security definer set search_path = public as $$
declare
  v_empresa uuid := minha_empresa();
  v_total integer;
  r record;
  i integer;
begin
  if meu_cargo() is distinct from 'gerente' then
    raise exception 'Apenas o gerente pode carregar os dados de demonstração.' using errcode = '42501';
  end if;
  if exists (select 1 from produtos where empresa_id = v_empresa) then
    raise exception 'A empresa já possui produtos cadastrados.';
  end if;

  insert into produtos (empresa_id, nome, categoria, codigo_barras, preco, quantidade, estoque_minimo, estoque_maximo, validade)
  values
    (v_empresa, 'Leite integral 1L', 'Laticínios', '7891000100103', 5.49, 48, 20, 120, current_date + 4),
    (v_empresa, 'Iogurte natural 170g', 'Laticínios', '7891000053508', 3.29, 6, 15, 60, current_date + 2),
    (v_empresa, 'Queijo mussarela 500g', 'Laticínios', null, 24.90, 12, 5, 30, current_date + 12),
    (v_empresa, 'Manteiga 200g', 'Laticínios', null, 11.90, 18, 8, 40, current_date + 28),
    (v_empresa, 'Pão de forma 500g', 'Padaria', null, 8.99, 9, 10, 40, current_date + 6),
    (v_empresa, 'Bolo de chocolate', 'Padaria', null, 19.90, 3, 2, 10, current_date + 1),
    (v_empresa, 'Arroz tipo 1 5kg', 'Mercearia', '7896006716112', 27.90, 35, 10, 80, current_date + 240),
    (v_empresa, 'Feijão carioca 1kg', 'Mercearia', '7896006751113', 8.49, 4, 12, 60, current_date + 180),
    (v_empresa, 'Açúcar refinado 1kg', 'Mercearia', null, 4.99, 22, 10, 60, current_date + 365),
    (v_empresa, 'Café torrado 500g', 'Mercearia', '7896005800027', 17.90, 14, 10, 50, current_date + 150),
    (v_empresa, 'Óleo de soja 900ml', 'Mercearia', null, 7.29, 0, 10, 50, current_date + 300),
    (v_empresa, 'Macarrão espaguete 500g', 'Mercearia', null, 4.59, 40, 15, 80, current_date + 400),
    (v_empresa, 'Molho de tomate 340g', 'Mercearia', null, 3.19, 25, 10, 60, current_date + 20),
    (v_empresa, 'Refrigerante cola 2L', 'Bebidas', '7894900011517', 9.99, 30, 12, 72, current_date + 90),
    (v_empresa, 'Água mineral 500ml', 'Bebidas', null, 2.49, 60, 24, 144, current_date + 365),
    (v_empresa, 'Suco de laranja 1L', 'Bebidas', null, 7.90, 8, 10, 40, current_date + 9),
    (v_empresa, 'Cerveja lata 350ml', 'Bebidas', null, 4.29, 96, 48, 240, current_date + 120),
    (v_empresa, 'Detergente 500ml', 'Limpeza', null, 2.79, 20, 10, 50, null),
    (v_empresa, 'Sabão em pó 1kg', 'Limpeza', null, 14.90, 5, 6, 30, null),
    (v_empresa, 'Papel higiênico 12un', 'Higiene', null, 21.90, 16, 8, 40, null),
    (v_empresa, 'Creme dental 90g', 'Higiene', null, 4.49, 2, 10, 50, current_date + 500),
    (v_empresa, 'Banana prata (kg)', 'Hortifruti', null, 6.99, 15, 10, 40, current_date + 3),
    (v_empresa, 'Tomate (kg)', 'Hortifruti', null, 8.49, 10, 8, 30, current_date + 5),
    (v_empresa, 'Ovos brancos 12un', 'Hortifruti', null, 12.90, 20, 10, 50, current_date + 14),
    (v_empresa, 'Presunto fatiado 200g', 'Frios', null, 9.90, 7, 5, 25, current_date + 7);

  -- Histórico de vendas dos últimos 7 dias para alimentar dashboard e giro.
  for i in 1..7 loop
    for r in select id, nome, preco from produtos
              where empresa_id = v_empresa and quantidade > 20
              order by random() limit 4 loop
      insert into vendas (empresa_id, operador_id, produto_id, produto_nome, quantidade, preco_unitario, total, created_at)
      values (v_empresa, auth.uid(), r.id, r.nome, 2, r.preco, r.preco * 2,
              now() - make_interval(days => i) + make_interval(hours => (random() * 8)::int));
    end loop;
  end loop;

  select count(*) into v_total from produtos where empresa_id = v_empresa;
  return v_total;
end $$;

-- ---------------------------------------------------------------------------
-- Permissões da API (explícitas, não dependem da opção "expose new tables").
-- O acesso linha a linha continua controlado pelo RLS acima.
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
grant execute on function public.empresa_por_codigo(text) to anon;

-- =============================================================================
-- Descontos e promoções (mesmo conteúdo de migrations/002_descontos_promocoes.sql)

-- Tabela de descontos sugeridos (percentual por faixa de dias até vencer).
-- 0 = não sugerir desconto naquela faixa.
alter table public.empresas
  add column if not exists desconto_1d integer not null default 50,
  add column if not exists desconto_3d integer not null default 30,
  add column if not exists desconto_5d integer not null default 20,
  add column if not exists desconto_6d integer not null default 10;

do $$ begin
  alter table public.empresas add constraint empresas_descontos_ck check (
    desconto_1d between 0 and 90 and desconto_3d between 0 and 90 and
    desconto_5d between 0 and 90 and desconto_6d between 0 and 90);
exception when duplicate_object then null; end $$;

-- Promoção ativa no produto (definida pelo gerente).
alter table public.produtos
  add column if not exists promocao_percentual integer,
  add column if not exists preco_promocional numeric(12, 2);

do $$ begin
  alter table public.produtos add constraint produtos_promocao_ck check (
    (promocao_percentual is null and preco_promocional is null) or
    (promocao_percentual between 1 and 90 and preco_promocional > 0));
exception when duplicate_object then null; end $$;

-- Venda guarda o desconto aplicado (histórico).
alter table public.vendas
  add column if not exists desconto_percentual integer not null default 0;

-- ---------------------------------------------------------------------------
-- Regras de produto: a promoção só muda pela RPC; se o preço for editado,
-- o preço promocional é recalculado automaticamente.
-- ---------------------------------------------------------------------------
create or replace function public.tg_produto_regras()
returns trigger language plpgsql as $$
begin
  if new.quantidade <> old.quantidade
     and coalesce(current_setting('cei.via_rpc', true), '') <> 'on' then
    raise exception 'A quantidade só pode ser alterada por uma movimentação de estoque.'
      using errcode = 'P0001';
  end if;
  if new.ativo <> old.ativo and public.meu_cargo() is distinct from 'gerente' then
    raise exception 'Apenas o gerente pode excluir ou restaurar produtos.'
      using errcode = '42501';
  end if;
  if new.empresa_id <> old.empresa_id then
    raise exception 'Não é permitido trocar a empresa do produto.' using errcode = '42501';
  end if;
  if (new.promocao_percentual is distinct from old.promocao_percentual
      or new.preco_promocional is distinct from old.preco_promocional)
     and coalesce(current_setting('cei.via_promo', true), '') <> 'on' then
    raise exception 'A promoção só pode ser alterada pelo gerente na tela do produto.'
      using errcode = '42501';
  end if;
  if new.preco <> old.preco and new.promocao_percentual is not null then
    new.preco_promocional := round(new.preco * (100 - new.promocao_percentual) / 100.0, 2);
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
create or replace function public.atualizar_descontos(
  p_1d integer, p_3d integer, p_5d integer, p_6d integer
) returns public.empresas
language plpgsql security definer set search_path = public as $$
declare
  v_empresa empresas;
begin
  if meu_cargo() is distinct from 'gerente' then
    raise exception 'Apenas o gerente pode alterar a tabela de descontos.' using errcode = '42501';
  end if;
  if least(p_1d, p_3d, p_5d, p_6d) < 0 or greatest(p_1d, p_3d, p_5d, p_6d) > 90 then
    raise exception 'Os descontos devem ficar entre 0%% e 90%%.';
  end if;
  update empresas
     set desconto_1d = p_1d, desconto_3d = p_3d, desconto_5d = p_5d, desconto_6d = p_6d
   where id = minha_empresa()
  returning * into v_empresa;
  return v_empresa;
end $$;

-- p_percentual null ou 0 encerra a promoção.
create or replace function public.aplicar_promocao(p_produto uuid, p_percentual integer)
returns public.produtos
language plpgsql security definer set search_path = public as $$
declare
  v_produto produtos;
begin
  if meu_cargo() is distinct from 'gerente' then
    raise exception 'Apenas o gerente pode aplicar ou encerrar promoções.' using errcode = '42501';
  end if;
  if p_percentual is not null and p_percentual <> 0 and (p_percentual < 1 or p_percentual > 90) then
    raise exception 'O desconto deve ficar entre 1%% e 90%%.';
  end if;

  perform set_config('cei.via_promo', 'on', true);
  update produtos
     set promocao_percentual = nullif(p_percentual, 0),
         preco_promocional = case when coalesce(p_percentual, 0) = 0 then null
                                  else round(preco * (100 - p_percentual) / 100.0, 2) end
   where id = p_produto and empresa_id = minha_empresa() and ativo
  returning * into v_produto;

  if not found then
    raise exception 'Produto não encontrado.';
  end if;
  return v_produto;
end $$;

-- Venda usa o preço promocional quando houver.
create or replace function public.registrar_venda(
  p_id uuid,
  p_produto uuid,
  p_quantidade integer
) returns public.vendas
language plpgsql security definer set search_path = public as $$
declare
  v_empresa uuid := minha_empresa();
  v_produto produtos;
  v_venda vendas;
  v_preco numeric(12, 2);
begin
  if v_empresa is null then
    raise exception 'Sessão inválida. Entre novamente.' using errcode = '42501';
  end if;
  if meu_cargo() not in ('gerente', 'vendedor', 'caixa') then
    raise exception 'Você não tem permissão para registrar vendas.' using errcode = '42501';
  end if;
  select * into v_venda from vendas where id = p_id;
  if found then
    return v_venda;
  end if;
  if p_quantidade is null or p_quantidade <= 0 then
    raise exception 'Informe uma quantidade válida.';
  end if;

  select * into v_produto from produtos
   where id = p_produto and empresa_id = v_empresa and ativo
   for update;
  if not found then
    raise exception 'Produto não encontrado.';
  end if;
  if v_produto.quantidade < p_quantidade then
    raise exception 'Estoque insuficiente: há apenas % unidade(s) de %.', v_produto.quantidade, v_produto.nome;
  end if;

  v_preco := coalesce(v_produto.preco_promocional, v_produto.preco);

  perform set_config('cei.via_rpc', 'on', true);
  update produtos set quantidade = quantidade - p_quantidade where id = p_produto;

  insert into movimentacoes (empresa_id, produto_id, usuario_id, tipo, quantidade, saldo_apos, observacao)
  values (v_empresa, p_produto, auth.uid(), 'venda', p_quantidade,
          v_produto.quantidade - p_quantidade, 'Venda');

  insert into vendas (id, empresa_id, operador_id, produto_id, produto_nome, quantidade,
                      preco_unitario, total, desconto_percentual)
  values (p_id, v_empresa, auth.uid(), p_produto, v_produto.nome, p_quantidade,
          v_preco, round(v_preco * p_quantidade, 2), coalesce(v_produto.promocao_percentual, 0))
  returning * into v_venda;
  return v_venda;
end $$;

grant execute on function public.atualizar_descontos(integer, integer, integer, integer) to authenticated;
grant execute on function public.aplicar_promocao(uuid, integer) to authenticated;
