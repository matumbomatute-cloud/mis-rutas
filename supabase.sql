-- Sobre Mis Rutas: tablas, permisos y fotos (versión con compartir).
-- Pégalo entero en Supabase > SQL Editor > New query y pulsa Run.
-- Si ya ejecutaste una versión anterior, ejecuta este igualmente: no borra tus datos.

-- 1) Sitios -----------------------------------------------------------
create table if not exists public.sites (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists sites_user_updated_idx on public.sites (user_id, updated_at);
create index if not exists sites_updated_idx on public.sites (updated_at);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists sites_touch on public.sites;
create trigger sites_touch before insert or update on public.sites
for each row execute function public.touch_updated_at();

-- 2) Quién comparte con quién ------------------------------------------
create table if not exists public.shares (
  owner_id uuid not null references auth.users(id) on delete cascade,
  shared_with uuid not null references auth.users(id) on delete cascade,
  owner_email text not null,
  shared_email text not null,
  can_edit boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (owner_id, shared_with),
  check (owner_id <> shared_with)
);
create index if not exists shares_shared_with_idx on public.shares (shared_with);

-- 3) Funciones de apoyo para las reglas ---------------------------------
create or replace function public.can_read_owner(o text)
returns boolean language sql stable security definer set search_path = '' as $$
  select o = auth.uid()::text
      or exists (select 1 from public.shares s
                 where s.owner_id::text = o and s.shared_with = auth.uid());
$$;

create or replace function public.can_write_owner(o text)
returns boolean language sql stable security definer set search_path = '' as $$
  select o = auth.uid()::text
      or exists (select 1 from public.shares s
                 where s.owner_id::text = o and s.shared_with = auth.uid() and s.can_edit);
$$;

grant execute on function public.can_read_owner(text) to authenticated;
grant execute on function public.can_write_owner(text) to authenticated;

-- 4) Compartir por correo (solo con personas que ya tienen cuenta) -------
create or replace function public.share_with(p_email text, p_can_edit boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := auth.uid();
  v_me_email text;
  v_target uuid;
  v_target_email text;
begin
  if v_me is null then raise exception 'not_authenticated'; end if;
  select id, email into v_target, v_target_email
    from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if v_target is null then raise exception 'user_not_found'; end if;
  if v_target = v_me then raise exception 'self_share'; end if;
  select email into v_me_email from auth.users where id = v_me;
  insert into public.shares (owner_id, shared_with, owner_email, shared_email, can_edit)
  values (v_me, v_target, v_me_email, v_target_email, coalesce(p_can_edit, false))
  on conflict (owner_id, shared_with) do update set can_edit = excluded.can_edit;
end;
$$;

revoke all on function public.share_with(text, boolean) from public, anon;
grant execute on function public.share_with(text, boolean) to authenticated;

-- 5) Reglas de seguridad ---------------------------------------------------
alter table public.sites enable row level security;
alter table public.shares enable row level security;

drop policy if exists "own sites" on public.sites;
drop policy if exists "sites select" on public.sites;
drop policy if exists "sites insert" on public.sites;
drop policy if exists "sites update" on public.sites;
drop policy if exists "sites delete" on public.sites;

create policy "sites select" on public.sites for select
  using (public.can_read_owner(user_id::text));
create policy "sites insert" on public.sites for insert
  with check (public.can_write_owner(user_id::text));
create policy "sites update" on public.sites for update
  using (public.can_write_owner(user_id::text))
  with check (public.can_write_owner(user_id::text));
create policy "sites delete" on public.sites for delete
  using (public.can_write_owner(user_id::text));

drop policy if exists "shares select" on public.shares;
drop policy if exists "shares delete" on public.shares;
create policy "shares select" on public.shares for select
  using (auth.uid() = owner_id or auth.uid() = shared_with);
create policy "shares delete" on public.shares for delete
  using (auth.uid() = owner_id or auth.uid() = shared_with);

revoke all on public.sites from anon;
revoke all on public.shares from anon;
grant select, insert, update, delete on public.sites to authenticated;
grant select, delete on public.shares to authenticated;

-- 6) Cambios en vivo entre dispositivos ----------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.sites;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.shares;
exception when duplicate_object then null;
end $$;

-- 7) Fotos: privadas; cada persona en su carpeta; las compartidas se pueden ver ---
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

drop policy if exists "own photos" on storage.objects;
drop policy if exists "photos read" on storage.objects;
drop policy if exists "photos insert" on storage.objects;
drop policy if exists "photos update" on storage.objects;
drop policy if exists "photos delete" on storage.objects;

create policy "photos read" on storage.objects for select
  using (bucket_id = 'photos' and public.can_read_owner((storage.foldername(name))[1]));
create policy "photos insert" on storage.objects for insert
  with check (bucket_id = 'photos' and public.can_write_owner((storage.foldername(name))[1]));
create policy "photos update" on storage.objects for update
  using (bucket_id = 'photos' and public.can_write_owner((storage.foldername(name))[1]))
  with check (bucket_id = 'photos' and public.can_write_owner((storage.foldername(name))[1]));
create policy "photos delete" on storage.objects for delete
  using (bucket_id = 'photos' and public.can_write_owner((storage.foldername(name))[1]));


-- 8) Avatares de perfil: privados; cada persona solo ve y cambia el suyo -----
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('profile-avatars', 'profile-avatars', false, 3145728, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profile avatars read own" on storage.objects;
drop policy if exists "profile avatars insert own" on storage.objects;
drop policy if exists "profile avatars update own" on storage.objects;
drop policy if exists "profile avatars delete own" on storage.objects;

create policy "profile avatars read own" on storage.objects for select to authenticated
  using (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "profile avatars insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "profile avatars update own" on storage.objects for update to authenticated
  using (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "profile avatars delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'profile-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
