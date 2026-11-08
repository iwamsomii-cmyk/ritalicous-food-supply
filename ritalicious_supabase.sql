-- =====================================================================
-- RITALICIOUS FOOD SUPPLY - kuunganisha vifaa kwa wakati halisi (real time)
-- Endesha FAILI HILI MOJA KWA MOJA kwenye Supabase > SQL Editor > Run.
-- Ni salama kuliendesha tena (idempotent). Majina yote yana kiambishi "rit_"
-- hivyo linaweza kukaa kwenye project moja na mifumo mingine (mf. TAG).
-- Usiweke kamwe service_role/secret key ndani ya app.
-- =====================================================================

-- ---------------------------------------------------------------- tables
create table if not exists public.rit_businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.rit_members (
  business_id uuid not null references public.rit_businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','editor')),
  status text not null default 'active' check (status in ('active','disabled')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);
create index if not exists idx_rit_members_user on public.rit_members(user_id);

create table if not exists public.rit_devices (
  business_id uuid not null references public.rit_businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  device_name text,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (business_id, device_id)
);

-- Rekodi zote zinazosawazishwa (sales, expenses, inventory, archives).
-- updated_at  = saa ya kifaa kilichobadilisha (mshindi = mpya zaidi)
-- synced_at   = saa ya seva (kila kifaa kinapakua rekodi mpya kwa kutumia hii)
create table if not exists public.rit_sync_records (
  business_id uuid not null references public.rit_businesses(id) on delete cascade,
  entity_type text not null check (entity_type in ('sales','expenses','inventory','archives')),
  sync_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null,
  synced_at timestamptz not null default clock_timestamp(),
  deleted boolean not null default false,
  device_id text,
  updated_by uuid references auth.users(id),
  primary key (business_id, entity_type, sync_id)
);
create index if not exists idx_rit_sync_synced on public.rit_sync_records(business_id, synced_at);

-- Namba za muda za kuunganisha kifaa kipya (zinahifadhiwa kama hash tu).
create table if not exists public.rit_pairing_codes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.rit_businesses(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  token_hash text not null,
  role text not null default 'editor' check (role in ('editor')),
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by uuid,
  used_device_name text,
  created_at timestamptz not null default now()
);
create index if not exists idx_rit_pair_code on public.rit_pairing_codes(code_hash) where used_at is null;
create index if not exists idx_rit_pair_token on public.rit_pairing_codes(token_hash) where used_at is null;

-- Kuzuia kubahatisha namba (majaribio mabaya).
create table if not exists public.rit_pairing_attempts (
  id bigserial primary key,
  user_id uuid not null,
  attempted_at timestamptz not null default now()
);
create index if not exists idx_rit_attempts on public.rit_pairing_attempts(user_id, attempted_at);

-- --------------------------------------------------------------- helpers
create or replace function public.rit_is_member(p_business uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.rit_members m
    where m.business_id = p_business and m.user_id = auth.uid() and m.status = 'active'
  );
$$;

create or replace function public.rit_role(p_business uuid)
returns text language sql stable security definer set search_path = public as $$
  select m.role from public.rit_members m
  where m.business_id = p_business and m.user_id = auth.uid() and m.status = 'active'
  limit 1;
$$;

create or replace function public.rit_h(t text)
returns text language sql immutable as $$
  select encode(sha256(convert_to(coalesce(t, ''), 'UTF8')), 'hex');
$$;

-- ------------------------------------------------- row level security
alter table public.rit_businesses enable row level security;
alter table public.rit_members enable row level security;
alter table public.rit_devices enable row level security;
alter table public.rit_sync_records enable row level security;
alter table public.rit_pairing_codes enable row level security;
alter table public.rit_pairing_attempts enable row level security;

drop policy if exists rit_businesses_select on public.rit_businesses;
create policy rit_businesses_select on public.rit_businesses for select to authenticated
  using (public.rit_is_member(id));

drop policy if exists rit_members_select on public.rit_members;
create policy rit_members_select on public.rit_members for select to authenticated
  using (user_id = auth.uid() or public.rit_is_member(business_id));

drop policy if exists rit_devices_select on public.rit_devices;
create policy rit_devices_select on public.rit_devices for select to authenticated
  using (public.rit_is_member(business_id));

drop policy if exists rit_sync_select on public.rit_sync_records;
create policy rit_sync_select on public.rit_sync_records for select to authenticated
  using (public.rit_is_member(business_id));

-- Kuandika kunafanyika kupitia kazi (functions) pekee; hakuna ruhusa ya moja kwa moja.
revoke all on public.rit_businesses, public.rit_members, public.rit_devices,
  public.rit_sync_records, public.rit_pairing_codes, public.rit_pairing_attempts from anon, authenticated;
grant select on public.rit_businesses, public.rit_members, public.rit_devices,
  public.rit_sync_records to authenticated;

-- -------------------------------------------------------- RPC functions
-- Kifaa cha kwanza kinaanzisha biashara na kuwa admin.
create or replace function public.rit_create_business(p_name text, p_device_id text, p_device_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_name text := trim(coalesce(p_name, ''));
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if length(v_name) < 2 then raise exception 'NAME_TOO_SHORT'; end if;
  if exists (select 1 from public.rit_members where user_id = v_uid and status = 'active') then
    raise exception 'ALREADY_LINKED';
  end if;
  insert into public.rit_businesses(name, created_by) values (v_name, v_uid) returning id into v_id;
  insert into public.rit_members(business_id, user_id, role) values (v_id, v_uid, 'admin');
  insert into public.rit_devices(business_id, user_id, device_id, device_name)
    values (v_id, v_uid, p_device_id, left(coalesce(p_device_name, ''), 40));
  return jsonb_build_object('business_id', v_id, 'business_name', v_name, 'role', 'admin');
end;
$$;

-- Admin anatengeneza QR/namba ya tarakimu 8 (dakika 10, mara moja tu).
create or replace function public.rit_create_pairing_code(p_business uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_token text;
  v_id uuid;
  v_exp timestamptz := now() + interval '10 minutes';
  v_try int := 0;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if public.rit_role(p_business) is distinct from 'admin' then raise exception 'ADMIN_ONLY'; end if;

  -- namba za zamani ambazo hazijatumika zinafutwa
  update public.rit_pairing_codes set expires_at = now()
    where business_id = p_business and used_at is null and expires_at > now();

  loop
    v_try := v_try + 1;
    v_code := lpad(
      ((('x' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))::bit(32)::bigint) % 100000000)::text,
      8, '0');
    exit when not exists (
      select 1 from public.rit_pairing_codes
      where code_hash = public.rit_h(v_code) and used_at is null and expires_at > now()
    ) or v_try >= 8;
  end loop;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  insert into public.rit_pairing_codes(business_id, created_by, code_hash, token_hash, expires_at)
    values (p_business, v_uid, public.rit_h(v_code), public.rit_h(v_token), v_exp)
    returning id into v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'token', v_token, 'expires_at', v_exp);
end;
$$;

-- Admin anaangalia kama namba yake imetumika (na kifaa gani).
create or replace function public.rit_pairing_status(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select used_at, used_device_name into r from public.rit_pairing_codes
    where id = p_id and created_by = auth.uid();
  if not found then return jsonb_build_object('used', false); end if;
  return jsonb_build_object('used', r.used_at is not null, 'device_name', coalesce(r.used_device_name, ''));
end;
$$;

-- Kifaa kipya kinatumia QR (token) au namba ya tarakimu 8.
create or replace function public.rit_redeem_pairing_code(p_secret text, p_device_id text, p_device_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_s text := regexp_replace(coalesce(p_secret, ''), '\s', '', 'g');
  v_fails int;
  rec public.rit_pairing_codes%rowtype;
  v_bname text;
begin
  if v_uid is null then raise exception 'NOT_AUTHENTICATED'; end if;

  delete from public.rit_pairing_attempts where attempted_at < now() - interval '1 day';
  select count(*) into v_fails from public.rit_pairing_attempts
    where user_id = v_uid and attempted_at > now() - interval '10 minutes';
  if v_fails >= 8 then
    return jsonb_build_object('ok', false, 'error', 'TOO_MANY');
  end if;

  select * into rec from public.rit_pairing_codes
    where used_at is null and expires_at > now()
      and (code_hash = public.rit_h(v_s) or token_hash = public.rit_h(v_s))
    order by created_at desc limit 1
    for update;

  if not found then
    insert into public.rit_pairing_attempts(user_id) values (v_uid);
    return jsonb_build_object('ok', false, 'error', 'INVALID');
  end if;

  -- kifaa kinaweza kuwa kwenye biashara moja tu kwa wakati mmoja
  update public.rit_members set status = 'disabled'
    where user_id = v_uid and business_id <> rec.business_id and status = 'active';

  insert into public.rit_members(business_id, user_id, role, status)
    values (rec.business_id, v_uid, rec.role, 'active')
    on conflict (business_id, user_id) do update set status = 'active', role = excluded.role;

  insert into public.rit_devices(business_id, user_id, device_id, device_name, last_seen_at, revoked_at)
    values (rec.business_id, v_uid, p_device_id, left(coalesce(p_device_name, ''), 40), now(), null)
    on conflict (business_id, device_id) do update
      set user_id = excluded.user_id, device_name = excluded.device_name,
          last_seen_at = now(), revoked_at = null;

  update public.rit_pairing_codes
    set used_at = now(), used_by = v_uid, used_device_name = left(coalesce(p_device_name, ''), 40)
    where id = rec.id;

  select name into v_bname from public.rit_businesses where id = rec.business_id;
  return jsonb_build_object('ok', true, 'business_id', rec.business_id, 'business_name', v_bname, 'role', rec.role);
end;
$$;

-- Tuma kundi la rekodi. Rekodi mpya zaidi (updated_at) ndiyo inashinda.
create or replace function public.rit_upsert_batch(p_business uuid, p_device_id text, p_rows jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare
  r jsonb;
  n integer := 0;
  v_uid uuid := auth.uid();
begin
  if not public.rit_is_member(p_business) then raise exception 'NO_ACCESS'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'BAD_ROWS'; end if;
  if jsonb_array_length(p_rows) > 500 then raise exception 'TOO_MANY_ROWS'; end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    insert into public.rit_sync_records
      (business_id, entity_type, sync_id, payload, updated_at, synced_at, deleted, device_id, updated_by)
    values
      (p_business, r->>'entity_type', (r->>'sync_id')::uuid, coalesce(r->'payload', '{}'::jsonb),
       (r->>'updated_at')::timestamptz, clock_timestamp(),
       coalesce((r->>'deleted')::boolean, false), p_device_id, v_uid)
    on conflict (business_id, entity_type, sync_id) do update set
      payload = excluded.payload,
      updated_at = excluded.updated_at,
      synced_at = excluded.synced_at,
      deleted = excluded.deleted,
      device_id = excluded.device_id,
      updated_by = excluded.updated_by
    where public.rit_sync_records.updated_at < excluded.updated_at;
    if found then n := n + 1; end if;
  end loop;
  return n;
end;
$$;

-- "Last seen" ya kifaa (inaonyesha Online/Offline).
create or replace function public.rit_touch_device(p_business uuid, p_device_id text, p_device_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.rit_is_member(p_business) then raise exception 'NO_ACCESS'; end if;
  insert into public.rit_devices(business_id, user_id, device_id, device_name, last_seen_at)
    values (p_business, auth.uid(), p_device_id, left(coalesce(p_device_name, ''), 40), now())
    on conflict (business_id, device_id) do update
      set last_seen_at = now(),
          device_name = coalesce(nullif(excluded.device_name, ''), public.rit_devices.device_name)
      where public.rit_devices.revoked_at is null and public.rit_devices.user_id = auth.uid();
end;
$$;

-- Admin anaondoa kifaa.
create or replace function public.rit_revoke_device(p_business uuid, p_device_id text)
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid;
begin
  if public.rit_role(p_business) is distinct from 'admin' then raise exception 'ADMIN_ONLY'; end if;
  select user_id into v_user from public.rit_devices where business_id = p_business and device_id = p_device_id;
  if v_user is null then return; end if;
  if v_user = auth.uid() then raise exception 'CANNOT_REVOKE_SELF'; end if;
  update public.rit_devices set revoked_at = now() where business_id = p_business and device_id = p_device_id;
  update public.rit_members set status = 'disabled' where business_id = p_business and user_id = v_user;
end;
$$;

-- Kifaa kinajitenga chenyewe.
create or replace function public.rit_leave_business(p_business uuid, p_device_id text)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if public.rit_role(p_business) is null then return; end if;
  if public.rit_role(p_business) = 'admin' and exists (
    select 1 from public.rit_members
    where business_id = p_business and status = 'active' and user_id <> v_uid
  ) then
    raise exception 'LAST_ADMIN';
  end if;
  update public.rit_members set status = 'disabled' where business_id = p_business and user_id = v_uid;
  update public.rit_devices set revoked_at = now()
    where business_id = p_business and device_id = p_device_id and user_id = v_uid;
  if not exists (select 1 from public.rit_members where business_id = p_business and status = 'active') then
    delete from public.rit_businesses where id = p_business;
  end if;
end;
$$;

-- ------------------------------------------------------------- privileges
revoke execute on function
  public.rit_create_business(text, text, text),
  public.rit_create_pairing_code(uuid),
  public.rit_pairing_status(uuid),
  public.rit_redeem_pairing_code(text, text, text),
  public.rit_upsert_batch(uuid, text, jsonb),
  public.rit_touch_device(uuid, text, text),
  public.rit_revoke_device(uuid, text),
  public.rit_leave_business(uuid, text),
  public.rit_is_member(uuid),
  public.rit_role(uuid)
  from public, anon;

grant execute on function
  public.rit_create_business(text, text, text),
  public.rit_create_pairing_code(uuid),
  public.rit_pairing_status(uuid),
  public.rit_redeem_pairing_code(text, text, text),
  public.rit_upsert_batch(uuid, text, jsonb),
  public.rit_touch_device(uuid, text, text),
  public.rit_revoke_device(uuid, text),
  public.rit_leave_business(uuid, text),
  public.rit_is_member(uuid),
  public.rit_role(uuid)
  to authenticated;

-- --------------------------------------------------------------- realtime
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'rit_sync_records') then
    alter publication supabase_realtime add table public.rit_sync_records;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'rit_devices') then
    alter publication supabase_realtime add table public.rit_devices;
  end if;
end $$;
