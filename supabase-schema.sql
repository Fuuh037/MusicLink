-- Music Link MVP — schema novo e isolado.
-- Cria tabelas ml_* para não conflitar com tabelas legadas profiles/artists.
-- Execute no SQL Editor do projeto Supabase antes de publicar o site.

begin;

create schema if not exists ml_private;
revoke all on schema ml_private from public, anon;
grant usage on schema ml_private to authenticated;

create table if not exists public.ml_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) between 2 and 80),
  role text not null default 'comum' check (role in ('admin', 'artista', 'comum')),
  created_at timestamptz not null default now()
);

create table if not exists public.ml_artists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.ml_profiles(user_id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 2 and 80),
  genre text not null check (char_length(trim(genre)) between 2 and 40),
  bio text not null check (char_length(trim(bio)) between 10 and 700),
  featured_track text check (featured_track is null or char_length(featured_track) <= 100),
  preview_path text,
  instagram_url text,
  website_url text,
  public_contact_email text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ml_contact_messages (
  id uuid primary key default gen_random_uuid(),
  sender_name text not null check (char_length(trim(sender_name)) between 2 and 80),
  sender_email text not null check (char_length(trim(sender_email)) between 5 and 254),
  subject text not null check (char_length(trim(subject)) between 2 and 120),
  message text not null check (char_length(trim(message)) between 10 and 3000),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists ml_artists_public_idx on public.ml_artists (is_published, created_at desc);
create index if not exists ml_artists_genre_idx on public.ml_artists (genre);
create index if not exists ml_profiles_role_idx on public.ml_profiles (role);
create index if not exists ml_contact_messages_inbox_idx on public.ml_contact_messages (is_read, created_at desc);

create or replace function ml_private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.ml_profiles p
    where p.user_id = (select auth.uid()) and p.role = 'admin'
  );
$$;
revoke all on function ml_private.is_admin() from public, anon;
grant execute on function ml_private.is_admin() to authenticated;

create or replace function public.ml_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  name_value text;
  role_value text;
begin
  name_value := left(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 80);
  if char_length(name_value) < 2 then name_value := 'Novo usuário'; end if;
  role_value := case
    when new.raw_user_meta_data ->> 'account_type' = 'artista' then 'artista'
    else 'comum'
  end;
  insert into public.ml_profiles (user_id, full_name, role)
  values (new.id, name_value, role_value)
  on conflict (user_id) do nothing;
  return new;
end;
$$;
revoke all on function public.ml_handle_new_user() from public, anon, authenticated;
drop trigger if exists ml_on_auth_user_created on auth.users;
create trigger ml_on_auth_user_created
  after insert on auth.users
  for each row execute function public.ml_handle_new_user();

-- Importa perfis ligados à Auth do esquema antigo sem apagar nem alterar as tabelas legadas.
-- Isto mantém o acesso de contas existentes (inclusive a primeira conta admin).
do $$
begin
  if to_regclass('public.profiles') is not null then
    execute $migration$
      insert into public.ml_profiles (user_id, full_name, role)
      select p.auth_user_id,
        coalesce(nullif(left(trim(p.name), 80), ''), 'Novo usuário'),
        case when p.role in ('admin', 'artista') then p.role else 'comum' end
      from public.profiles p
      where p.auth_user_id is not null
      on conflict (user_id) do nothing
    $migration$;
  end if;
end;
$$;

create or replace function public.ml_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists ml_artists_set_updated_at on public.ml_artists;
create trigger ml_artists_set_updated_at
  before update on public.ml_artists
  for each row execute function public.ml_set_updated_at();

alter table public.ml_profiles enable row level security;
alter table public.ml_artists enable row level security;
alter table public.ml_contact_messages enable row level security;

revoke all on public.ml_profiles, public.ml_artists, public.ml_contact_messages from public, anon, authenticated;
grant select on public.ml_profiles to authenticated;
grant select on public.ml_artists to anon;
grant select, insert, update, delete on public.ml_artists to authenticated;
grant insert on public.ml_contact_messages to anon, authenticated;
grant select, update on public.ml_contact_messages to authenticated;

drop policy if exists ml_profiles_read_self_or_admin on public.ml_profiles;
create policy ml_profiles_read_self_or_admin on public.ml_profiles
  for select to authenticated
  using ((select auth.uid()) = user_id or (select ml_private.is_admin()));

drop policy if exists ml_artists_read_published on public.ml_artists;
create policy ml_artists_read_published on public.ml_artists
  for select to anon, authenticated
  using (is_published);

drop policy if exists ml_artists_read_owner_or_admin on public.ml_artists;
create policy ml_artists_read_owner_or_admin on public.ml_artists
  for select to authenticated
  using (owner_id = (select auth.uid()) or (select ml_private.is_admin()));

drop policy if exists ml_artists_create_artist_or_admin on public.ml_artists;
create policy ml_artists_create_artist_or_admin on public.ml_artists
  for insert to authenticated
  with check (
    (owner_id = (select auth.uid()) and exists (
      select 1 from public.ml_profiles p
      where p.user_id = (select auth.uid()) and p.role = 'artista'
    ))
    or (select ml_private.is_admin())
  );

drop policy if exists ml_artists_update_owner_or_admin on public.ml_artists;
create policy ml_artists_update_owner_or_admin on public.ml_artists
  for update to authenticated
  using (owner_id = (select auth.uid()) or (select ml_private.is_admin()))
  with check (owner_id = (select auth.uid()) or (select ml_private.is_admin()));

drop policy if exists ml_artists_delete_admin on public.ml_artists;
create policy ml_artists_delete_admin on public.ml_artists
  for delete to authenticated
  using ((select ml_private.is_admin()));

drop policy if exists ml_contact_messages_create on public.ml_contact_messages;
create policy ml_contact_messages_create on public.ml_contact_messages
  for insert to anon, authenticated
  with check (true);

drop policy if exists ml_contact_messages_admin_read on public.ml_contact_messages;
create policy ml_contact_messages_admin_read on public.ml_contact_messages
  for select to authenticated
  using ((select ml_private.is_admin()));

drop policy if exists ml_contact_messages_admin_update on public.ml_contact_messages;
create policy ml_contact_messages_admin_update on public.ml_contact_messages
  for update to authenticated
  using ((select ml_private.is_admin()))
  with check ((select ml_private.is_admin()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'artist-previews', 'artist-previews', true, 15728640,
  array['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/x-wav', 'audio/ogg', 'audio/mp4', 'audio/aac']
)
on conflict (id) do nothing;

drop policy if exists ml_artist_preview_insert on storage.objects;
create policy ml_artist_preview_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'artist-previews' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists ml_artist_preview_update on storage.objects;
create policy ml_artist_preview_update on storage.objects
  for update to authenticated
  using (bucket_id = 'artist-previews' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'artist-previews' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists ml_artist_preview_delete on storage.objects;
create policy ml_artist_preview_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'artist-previews' and (storage.foldername(name))[1] = (select auth.uid())::text);

notify pgrst, 'reload schema';
commit;

-- Ative uma conta de administrador manualmente após criar essa conta no site:
-- update public.ml_profiles set role = 'admin' where user_id = 'UUID-DA-CONTA';
-- Music Link — perfis públicos e métricas de visita (migração aditiva).
-- Não apaga dados nem altera tabelas legadas.

begin;

alter table public.ml_artists
  add column if not exists slug text,
  add column if not exists location text,
  add column if not exists avatar_path text,
  add column if not exists cover_path text;

update public.ml_artists
set slug = trim(both '-' from regexp_replace(lower(regexp_replace(display_name, '[^a-zA-Z0-9]+', '-', 'g')), '-+', '-', 'g')) || '-' || left(id::text, 6)
where slug is null or trim(slug) = '';

create unique index if not exists ml_artists_slug_uidx on public.ml_artists (slug) where slug is not null;
create index if not exists ml_artists_location_idx on public.ml_artists (location) where location is not null;

create table if not exists public.ml_artist_posts (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.ml_artists(id) on delete cascade,
  image_path text not null,
  caption text not null default '' check (char_length(caption) <= 280),
  created_at timestamptz not null default now()
);
create index if not exists ml_artist_posts_artist_idx on public.ml_artist_posts (artist_id, created_at desc);
alter table public.ml_artist_posts enable row level security;
revoke all on public.ml_artist_posts from public, anon, authenticated;
grant select on public.ml_artist_posts to anon, authenticated;
grant insert, update, delete on public.ml_artist_posts to authenticated;

drop policy if exists ml_artist_posts_read_visible on public.ml_artist_posts;
drop policy if exists ml_artist_posts_read_published on public.ml_artist_posts;
drop policy if exists ml_artist_posts_read_owner_admin on public.ml_artist_posts;
create policy ml_artist_posts_read_published on public.ml_artist_posts
  for select to anon
  using (exists (select 1 from public.ml_artists a where a.id = artist_id and a.is_published));
create policy ml_artist_posts_read_owner_admin on public.ml_artist_posts
  for select to authenticated
  using (
    exists (select 1 from public.ml_artists a where a.id = artist_id and a.is_published)
    or exists (select 1 from public.ml_artists a where a.id = artist_id and a.owner_id = (select auth.uid()))
    or (select ml_private.is_admin())
  );
drop policy if exists ml_artist_posts_create_owner on public.ml_artist_posts;
create policy ml_artist_posts_create_owner on public.ml_artist_posts
  for insert to authenticated
  with check (exists (select 1 from public.ml_artists a where a.id = artist_id and a.owner_id = (select auth.uid())));
drop policy if exists ml_artist_posts_update_owner on public.ml_artist_posts;
create policy ml_artist_posts_update_owner on public.ml_artist_posts
  for update to authenticated
  using (exists (select 1 from public.ml_artists a where a.id = artist_id and (a.owner_id = (select auth.uid()) or (select ml_private.is_admin()))))
  with check (exists (select 1 from public.ml_artists a where a.id = artist_id and (a.owner_id = (select auth.uid()) or (select ml_private.is_admin()))));
drop policy if exists ml_artist_posts_delete_owner on public.ml_artist_posts;
create policy ml_artist_posts_delete_owner on public.ml_artist_posts
  for delete to authenticated
  using (exists (select 1 from public.ml_artists a where a.id = artist_id and (a.owner_id = (select auth.uid()) or (select ml_private.is_admin()))));

create table if not exists public.ml_artist_views (
  id uuid primary key default gen_random_uuid(),
  artist_id uuid not null references public.ml_artists(id) on delete cascade,
  visitor_key uuid not null,
  viewed_on date not null default current_date,
  created_at timestamptz not null default now(),
  constraint ml_artist_views_daily_unique unique (artist_id, visitor_key, viewed_on)
);
create index if not exists ml_artist_views_artist_day_idx on public.ml_artist_views (artist_id, viewed_on desc);
alter table public.ml_artist_views enable row level security;
revoke all on public.ml_artist_views from public, anon, authenticated;
grant insert (artist_id, visitor_key) on public.ml_artist_views to anon, authenticated;
grant select on public.ml_artist_views to authenticated;

drop policy if exists ml_artist_views_record_published on public.ml_artist_views;
create policy ml_artist_views_record_published on public.ml_artist_views
  for insert to anon, authenticated
  with check (exists (select 1 from public.ml_artists a where a.id = artist_id and a.is_published));
drop policy if exists ml_artist_views_read_owner_admin on public.ml_artist_views;
create policy ml_artist_views_read_owner_admin on public.ml_artist_views
  for select to authenticated
  using (exists (select 1 from public.ml_artists a where a.id = artist_id and (a.owner_id = (select auth.uid()) or (select ml_private.is_admin()))));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('artist-media', 'artist-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists ml_artist_media_read_public on storage.objects;
create policy ml_artist_media_read_public on storage.objects
  for select to anon, authenticated using (bucket_id = 'artist-media');
drop policy if exists ml_artist_media_insert_owner on storage.objects;
create policy ml_artist_media_insert_owner on storage.objects
  for insert to authenticated
  with check (bucket_id = 'artist-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists ml_artist_media_update_owner on storage.objects;
create policy ml_artist_media_update_owner on storage.objects
  for update to authenticated
  using (bucket_id = 'artist-media' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'artist-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists ml_artist_media_delete_owner on storage.objects;
create policy ml_artist_media_delete_owner on storage.objects
  for delete to authenticated
  using (bucket_id = 'artist-media' and (storage.foldername(name))[1] = (select auth.uid())::text);

notify pgrst, 'reload schema';
commit;


