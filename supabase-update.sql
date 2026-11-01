-- ARQUIVO LEGADO / NÃO EXECUTAR NO FLUXO ATUAL.
-- Esta atualização modifica as tabelas públicas antigas `profiles` e `artists`.
-- O MVP ativo usa o esquema isolado `ml_*` de `supabase-schema.sql`.
-- Mantenha este arquivo apenas como referência histórica para uma migração planejada.
-- Atualização reexecutável: preserva tabelas, registros e identificadores.
-- Execute o arquivo inteiro no SQL Editor. Qualquer erro desfaz a transação.
-- Não substitui estruturas incompatíveis nem inventa dados ausentes.
begin;
set local lock_timeout = '10s';

create table if not exists public.profiles (
  id text primary key default gen_random_uuid()::text,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  name text not null check (char_length(name) between 2 and 80),
  role text not null default 'comum' check (role in ('admin','artista','comum')),
  created_at timestamptz not null default now()
);

do $$
declare id_type text;
begin
  select format_type(atttypid, atttypmod) into id_type from pg_attribute
  where attrelid = 'public.profiles'::regclass and attname = 'id' and not attisdropped;
  if id_type not in ('text','uuid','character varying') or id_type is null then
    raise exception 'profiles.id precisa ser text ou uuid. Envie a estrutura atual para adaptar sem alterar os IDs.';
  end if;
  if to_regclass('public.artists') is null then
    execute format($table$create table public.artists (
  id text primary key default gen_random_uuid()::text,
  owner_id %s not null constraint artists_owner_id_fkey references public.profiles(id) on delete restrict,
  name text not null check (char_length(name) between 2 and 80),
  genre text not null check (char_length(genre) between 2 and 40),
  song text not null check (char_length(song) between 2 and 100),
  bio text not null check (char_length(bio) between 10 and 500),
  instagram text not null default '',
  contact_email text not null default '',
  created_at timestamptz not null default now()
);
$table$, id_type);
  end if;
end $$;

-- Adicionar somente campos ausentes. Dados obrigatórios antigos não são preenchidos artificialmente.
alter table public.profiles
  add column if not exists auth_user_id uuid,
  add column if not exists name text,
  add column if not exists role text default 'comum',
  add column if not exists created_at timestamptz default now();
alter table public.artists
  add column if not exists name text,
  add column if not exists genre text,
  add column if not exists song text,
  add column if not exists bio text,
  add column if not exists instagram text default '',
  add column if not exists contact_email text default '',
  add column if not exists created_at timestamptz default now();

-- Conferir os tipos antes de instalar as regras de acesso.
do $$
declare p_type oid; owner_type oid; a_type oid; item record;
begin
  select atttypid into p_type from pg_attribute where attrelid='public.profiles'::regclass and attname='id' and not attisdropped;
  select atttypid into owner_type from pg_attribute where attrelid='public.artists'::regclass and attname='owner_id' and not attisdropped;
  select atttypid into a_type from pg_attribute where attrelid='public.artists'::regclass and attname='id' and not attisdropped;
  if owner_type is distinct from p_type or a_type is null or a_type not in ('text'::regtype,'uuid'::regtype,'varchar'::regtype) then
    raise exception 'IDs incompatíveis: artists deve ter id text/uuid e owner_id do mesmo tipo de profiles.id. Nenhum ID foi convertido.';
  end if;
  if (select atttypid from pg_attribute where attrelid='public.profiles'::regclass and attname='auth_user_id') <> 'uuid'::regtype then
    raise exception 'profiles.auth_user_id deve ser uuid. Envie a estrutura existente para adaptar.';
  end if;
  -- Substituir todas as políticas apenas destas duas tabelas.
  -- As políticas da migração são instaladas antes do COMMIT; erros restauram as antigas.
  -- %I trata corretamente nomes com espaços, pontos e outros caracteres.
  for item in select tablename,policyname from pg_policies
    where schemaname='public' and tablename in ('profiles','artists')
  loop
    execute format('drop policy %I on public.%I',item.policyname,item.tablename);
  end loop;
end $$;

-- Detectar dados inválidos antes de apertar as restrições (sem corrigir/excluir registros).
alter table public.profiles alter column name set not null, alter column role set not null,
  alter column role set default 'comum', alter column created_at set default now();
alter table public.artists alter column owner_id set not null, alter column name set not null,
  alter column genre set not null, alter column song set not null, alter column bio set not null,
  alter column instagram set default '', alter column contact_email set default '',
  alter column created_at set default now();

-- UUID é aceito nas bases já iniciadas; novas bases preservam IDs Appwrite em text.
do $$
declare t text; id_type text; constraint_row record;
begin
  foreach t in array array['profiles','artists'] loop
    if not exists (select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and contype='p') then
      execute format('alter table public.%I add primary key (id)',t);
    end if;
    select format_type(atttypid,atttypmod) into id_type from pg_attribute where attrelid=format('public.%I',t)::regclass and attname='id';
    if id_type='uuid' then
      execute format('alter table public.%I alter column id set default gen_random_uuid()',t);
    else
      execute format('alter table public.%I alter column id set default gen_random_uuid()::text',t);
    end if;
  end loop;
end $$;
create unique index if not exists music_link_profiles_auth_uid on public.profiles(auth_user_id);
create index if not exists artists_created_at_idx on public.artists(created_at desc);
create index if not exists artists_owner_id_idx on public.artists(owner_id);

-- Recriar apenas as constraints próprias desta atualização, dentro da transação.
alter table public.profiles drop constraint if exists music_link_profile_values;
alter table public.profiles add constraint music_link_profile_values
  check (char_length(name) between 2 and 80 and role in ('admin','artista','comum'));
alter table public.artists drop constraint if exists music_link_artist_values;
alter table public.artists add constraint music_link_artist_values check (
  char_length(name) between 2 and 80 and char_length(genre) between 2 and 40
  and char_length(song) between 2 and 100 and char_length(bio) between 10 and 500);

-- Garantir FKs sem duplicar relacionamentos usados pelo PostgREST.
do $$
declare existing_fk record;
begin
  if not exists (
    select 1 from pg_constraint c where c.conrelid='public.profiles'::regclass and c.contype='f'
    and c.confrelid='auth.users'::regclass
    and c.conkey=array[(select attnum from pg_attribute where attrelid='public.profiles'::regclass and attname='auth_user_id')]
    and c.confkey=array[(select attnum from pg_attribute where attrelid='auth.users'::regclass and attname='id')]
  ) then
    alter table public.profiles add constraint music_link_profiles_auth_fkey foreign key(auth_user_id) references auth.users(id) on delete set null;
  end if;
  select c.conname into existing_fk from pg_constraint c where c.conrelid='public.artists'::regclass
    and c.contype='f' and c.confrelid='public.profiles'::regclass
    and c.conkey=array[(select attnum from pg_attribute where attrelid='public.artists'::regclass and attname='owner_id')]
    and c.confkey=array[(select attnum from pg_attribute where attrelid='public.profiles'::regclass and attname='id')]
    order by (c.conname='artists_owner_id_fkey') desc limit 1;
  if existing_fk.conname is null then
    alter table public.artists add constraint artists_owner_id_fkey foreign key(owner_id) references public.profiles(id) on delete restrict;
  elsif existing_fk.conname <> 'artists_owner_id_fkey' then
    execute format('alter table public.artists rename constraint %I to artists_owner_id_fkey',existing_fk.conname);
  end if;
end $$;

-- Reaproveitar vínculos apenas quando uma FK existente comprova que profiles.id é auth.users.id.
do $$
begin
  if exists (select 1 from pg_constraint c where c.conrelid='public.profiles'::regclass
    and c.contype='f' and c.confrelid='auth.users'::regclass
    and c.conkey=array[(select attnum from pg_attribute where attrelid='public.profiles'::regclass and attname='id')]
    and c.confkey=array[(select attnum from pg_attribute where attrelid='auth.users'::regclass and attname='id')]) then
    update public.profiles p set auth_user_id=u.id from auth.users u
    where p.auth_user_id is null and p.id::text=u.id::text;
  end if;
end $$;

-- Remover também eventuais concessões por coluna: REVOKE na tabela não as remove.
do $$
declare item record;
begin
  for item in select table_name,column_name from information_schema.columns
    where table_schema='public' and table_name in ('profiles','artists') loop
    execute format('revoke all privileges (%I) on public.%I from public, anon, authenticated',item.column_name,item.table_name);
  end loop;
end $$;
alter table public.profiles enable row level security;
alter table public.artists enable row level security;
revoke all on public.profiles, public.artists from public, anon, authenticated;
grant select on public.profiles, public.artists to anon, authenticated;
grant insert (owner_id,name,genre,song,bio,instagram,contact_email), update (name,genre,song,bio,instagram,contact_email) on public.artists to authenticated;
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select to anon, authenticated using (true);
drop policy if exists artists_read on public.artists;
create policy artists_read on public.artists for select to anon, authenticated using (true);
drop policy if exists artists_create on public.artists;
create policy artists_create on public.artists for insert to authenticated with check (
  exists (select 1 from public.profiles p where p.auth_user_id = (select auth.uid()) and p.role in ('admin','artista') and p.id = owner_id)
);
drop policy if exists artists_update on public.artists;
create policy artists_update on public.artists for update to authenticated using (
  exists (select 1 from public.profiles p where p.auth_user_id = (select auth.uid()) and (p.role = 'admin' or (p.role = 'artista' and p.id = owner_id)))
) with check (
  exists (select 1 from public.profiles p where p.auth_user_id = (select auth.uid()) and (p.role = 'admin' or (p.role = 'artista' and p.id = owner_id)))
);
-- Mesmo nome do trigger anterior: uma única criação de perfil por cadastro.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
declare profile_name text;
begin
  profile_name := left(trim(new.raw_user_meta_data->>'name'),80);
  if profile_name is null or char_length(profile_name)<2 then profile_name := 'Novo usuário'; end if;
  insert into public.profiles(id,auth_user_id,name,role)
  values (new.id, new.id, profile_name, 'comum');
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
notify pgrst, 'reload schema';
commit;
