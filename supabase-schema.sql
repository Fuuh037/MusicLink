create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  role text not null default 'comum' check (role in ('admin', 'artista', 'comum')),
  created_at timestamptz not null default now()
);

create table if not exists public.artists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 2 and 80),
  genre text not null check (char_length(trim(genre)) between 2 and 40),
  song text not null check (char_length(trim(song)) between 2 and 100),
  bio text not null check (char_length(trim(bio)) between 10 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.artists enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text;
begin
  requested_role := new.raw_user_meta_data->>'role';

  insert into public.profiles (id, name, role)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), 'Novo usuario'),
    case
      when requested_role in ('artista', 'comum') then requested_role
      else 'comum'
    end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists artists_set_updated_at on public.artists;

create trigger artists_set_updated_at
before update on public.artists
for each row execute function public.set_updated_at();

drop policy if exists "Profiles are visible to everyone." on public.profiles;
drop policy if exists "Users can create their own non-admin profile." on public.profiles;
drop policy if exists "Users can update their own non-admin profile." on public.profiles;
drop policy if exists "Artists are visible to everyone." on public.artists;
drop policy if exists "Admins and artists can create artist profiles." on public.artists;
drop policy if exists "Admins can update any artist, artists can update their own." on public.artists;

create policy "Profiles are visible to everyone."
on public.profiles
for select
to anon, authenticated
using (true);

create policy "Users can create their own non-admin profile."
on public.profiles
for insert
to authenticated
with check (
  auth.uid() = id
  and role in ('artista', 'comum')
);

create policy "Users can update their own non-admin profile."
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (
  auth.uid() = id
  and role in ('artista', 'comum')
);

create policy "Artists are visible to everyone."
on public.artists
for select
to anon, authenticated
using (true);

create policy "Admins and artists can create artist profiles."
on public.artists
for insert
to authenticated
with check (
  owner_id = auth.uid()
  and exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
    and profiles.role in ('admin', 'artista')
  )
);

create policy "Admins can update any artist, artists can update their own."
on public.artists
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
    and profiles.role = 'admin'
  )
  or (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
      and profiles.role = 'artista'
    )
  )
)
with check (
  exists (
    select 1
    from public.profiles
    where profiles.id = auth.uid()
    and profiles.role = 'admin'
  )
  or (
    owner_id = auth.uid()
    and exists (
      select 1
      from public.profiles
      where profiles.id = auth.uid()
      and profiles.role = 'artista'
    )
  )
);

-- Depois que criar sua propria conta, rode um comando como este no SQL Editor
-- para transforma-la em administradora:
-- update public.profiles
-- set role = 'admin'
-- where id = (select id from auth.users where email = 'seu-email@exemplo.com');
