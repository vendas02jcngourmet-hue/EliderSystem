-- ESystemShop — banco de dados no Supabase
-- Cole este arquivo inteiro em: Supabase > SQL Editor > New query > Run
-- Pode rodar mais de uma vez sem perder dados.

-- =========================================================
-- TABELAS
-- =========================================================

create table if not exists public.produtos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome        text not null,
  sku         text,
  custo       numeric(12,2) not null default 0,
  preco       numeric(12,2) not null default 0,
  estoque     integer not null default 0,
  minimo      integer not null default 0,
  criado_em   timestamptz not null default now()
);

create table if not exists public.vendas (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data        date not null default current_date,
  pedido      text,
  produto_id  uuid references public.produtos(id) on delete set null,
  produto     text not null,               -- nome guardado na hora da venda
  qtd         integer not null check (qtd > 0),
  preco       numeric(12,2) not null,      -- preço unitário
  taxa        numeric(12,2) not null default 0,  -- taxa Shopee total do pedido
  taxa_auto   boolean not null default true,     -- true = calculada pela faixa
  outros      numeric(12,2) not null default 0,  -- frete, embalagem etc.
  custo_unit  numeric(12,2) not null default 0,
  origem      text not null default 'manual',    -- manual | upseller
  criado_em   timestamptz not null default now()
);

-- Evita lançar o mesmo pedido/produto duas vezes (útil na importação do UpSeller)
create unique index if not exists vendas_pedido_unico
  on public.vendas (user_id, pedido, produto_id)
  where pedido is not null and pedido <> '';

create index if not exists vendas_data_idx on public.vendas (user_id, data desc);

create table if not exists public.boletos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  descricao   text not null,
  fornecedor  text,
  valor       numeric(12,2) not null,
  vencimento  date not null,
  pago        boolean not null default false,
  pago_em     date,
  criado_em   timestamptz not null default now()
);

create index if not exists boletos_venc_idx on public.boletos (user_id, vencimento);

-- Faixas de taxa da Shopee (uma linha por usuário)
create table if not exists public.ajustes (
  user_id      uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  faixas       jsonb not null default '[
    {"ate":79.99,"pct":20,"fixo":4.5},
    {"ate":99.99,"pct":14,"fixo":16},
    {"ate":199.99,"pct":14,"fixo":20},
    {"ate":499.99,"pct":14,"fixo":26},
    {"ate":null,"pct":14,"fixo":26}
  ]'::jsonb,
  meio_abaixo  numeric(12,2) not null default 9,
  atualizado_em timestamptz not null default now()
);

-- =========================================================
-- SEGURANÇA: cada usuário só vê e altera os próprios dados
-- =========================================================

alter table public.produtos enable row level security;
alter table public.vendas   enable row level security;
alter table public.boletos  enable row level security;
alter table public.ajustes  enable row level security;

do $$
declare t text;
begin
  foreach t in array array['produtos','vendas','boletos','ajustes'] loop
    execute format('drop policy if exists "dono_select" on public.%I', t);
    execute format('drop policy if exists "dono_insert" on public.%I', t);
    execute format('drop policy if exists "dono_update" on public.%I', t);
    execute format('drop policy if exists "dono_delete" on public.%I', t);
    execute format('create policy "dono_select" on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
    execute format('create policy "dono_insert" on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t);
    execute format('create policy "dono_update" on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
    execute format('create policy "dono_delete" on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t);
  end loop;
end $$;

-- =========================================================
-- ESTOQUE AUTOMÁTICO
-- Lançar venda baixa o estoque; excluir venda devolve ao estoque.
-- =========================================================

create or replace function public.ajusta_estoque_venda()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if tg_op = 'INSERT' and new.produto_id is not null then
    update public.produtos set estoque = estoque - new.qtd
     where id = new.produto_id and user_id = new.user_id;
  elsif tg_op = 'DELETE' and old.produto_id is not null then
    update public.produtos set estoque = estoque + old.qtd
     where id = old.produto_id and user_id = old.user_id;
  end if;
  return null;
end $$;

drop trigger if exists vendas_estoque on public.vendas;
create trigger vendas_estoque
  after insert or delete on public.vendas
  for each row execute function public.ajusta_estoque_venda();
