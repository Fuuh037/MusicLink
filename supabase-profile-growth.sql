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

