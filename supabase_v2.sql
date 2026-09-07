-- MINHAS FINANÇAS v2
-- Execute este SQL DEPOIS do SQL anterior.
-- Ele adiciona convites, criação automática de carteira e cartões compartilhados.

create extension if not exists pgcrypto;

create table if not exists public.household_invites (
  code text primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.cards (
  id text primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  icon text default '💳',
  credit_limit numeric(14,2) not null default 0,
  closing_day integer not null default 1 check (closing_day between 1 and 31),
  due_day integer not null default 1 check (due_day between 1 and 31),
  updated_at timestamptz not null default now()
);

alter table public.household_invites enable row level security;
alter table public.cards enable row level security;

drop policy if exists "members can view cards" on public.cards;
drop policy if exists "members can insert cards" on public.cards;
drop policy if exists "members can update cards" on public.cards;
drop policy if exists "members can delete cards" on public.cards;

create policy "members can view cards"
on public.cards for select to authenticated
using (exists (
  select 1 from public.household_members hm
  where hm.household_id=cards.household_id and hm.user_id=auth.uid()
));

create policy "members can insert cards"
on public.cards for insert to authenticated
with check (
  user_id=auth.uid() and exists (
    select 1 from public.household_members hm
    where hm.household_id=cards.household_id and hm.user_id=auth.uid()
  )
);

create policy "members can update cards"
on public.cards for update to authenticated
using (exists (
  select 1 from public.household_members hm
  where hm.household_id=cards.household_id and hm.user_id=auth.uid()
))
with check (
  user_id=auth.uid() and exists (
    select 1 from public.household_members hm
    where hm.household_id=cards.household_id and hm.user_id=auth.uid()
  )
);

create policy "members can delete cards"
on public.cards for delete to authenticated
using (exists (
  select 1 from public.household_members hm
  where hm.household_id=cards.household_id and hm.user_id=auth.uid()
));

-- Cria uma carteira e já coloca o usuário como dono.
create or replace function public.create_household(p_name text default 'Minhas Finanças')
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  h public.households;
begin
  insert into public.households(name, created_by)
  values (coalesce(nullif(trim(p_name),''),'Minhas Finanças'), auth.uid())
  returning * into h;

  insert into public.household_members(household_id,user_id,role)
  values (h.id, auth.uid(), 'owner');

  return h;
end;
$$;

-- Gera um convite aleatório de 6 caracteres.
create or replace function public.create_household_invite(p_household_id uuid)
returns table(code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  c text;
begin
  if not exists (
    select 1 from public.household_members
    where household_id=p_household_id and user_id=auth.uid()
  ) then
    raise exception 'Você não pertence a esta carteira';
  end if;

  c := upper(substr(encode(gen_random_bytes(8),'hex'),1,6));

  insert into public.household_invites(code,household_id,created_by)
  values(c,p_household_id,auth.uid());

  return query select c;
end;
$$;

-- Aceita o convite e coloca o usuário na carteira.
create or replace function public.join_household(p_code text)
returns public.households
language plpgsql
security definer
set search_path = public
as $$
declare
  inv public.household_invites;
  h public.households;
begin
  select * into inv
  from public.household_invites
  where code=upper(trim(p_code))
    and used_at is null
    and expires_at > now()
  limit 1;

  if inv.code is null then
    raise exception 'Código inválido ou expirado';
  end if;

  select * into h from public.households where id=inv.household_id;

  insert into public.household_members(household_id,user_id,role)
  values(inv.household_id,auth.uid(),'member')
  on conflict do nothing;

  update public.household_invites
  set used_at=now()
  where code=inv.code;

  return h;
end;
$$;

-- Segurança: só usuários autenticados podem chamar as funções.
revoke all on function public.create_household(text) from public;
grant execute on function public.create_household(text) to authenticated;

revoke all on function public.create_household_invite(uuid) from public;
grant execute on function public.create_household_invite(uuid) to authenticated;

revoke all on function public.join_household(text) from public;
grant execute on function public.join_household(text) to authenticated;
