-- =============================================================================
-- Migração 002: tabela de descontos por empresa + promoções em produtos.
-- Rode no Supabase: SQL Editor > New query > colar este arquivo > Run.
-- Pode ser rodada mais de uma vez sem problema.
-- =============================================================================

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
