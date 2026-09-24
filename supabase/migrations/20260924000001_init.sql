-- ============================================================================
-- Garsie Army — database schema (Supabase / Postgres)
--
-- Design rules
--   * Every table has Row Level Security. The browser only ever uses the
--     publishable key; what a user may see or change is decided HERE.
--   * Roles come from public.admins (managed by a Hoof-admin in the app),
--     never from anything the user picks.
--   * Check-ins, QR codes and the attendee export are database functions
--     (security definer), so the QR secret, the location check and the
--     "Wie mag kom?" rules can't be bypassed from a phone.
--   * Sized for a school: a few hundred events a year, ~2000 users,
--     bursts of a few check-ins per second at big matches.
-- ============================================================================

create schema if not exists private;          -- not exposed through the API

-- ---------------------------------------------------------------- constants
create or replace function private.learner_grades() returns text[]
language sql immutable set search_path = '' as
$$ select array['Graad 8','Graad 9','Graad 10','Graad 11','Graad 12'] $$;

-- ---------------------------------------------------------------- tables
create table public.departments (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 2 and 30),
  colour     text not null check (colour ~ '^#[0-9a-fA-F]{6}$'),
  created_at timestamptz not null default now()
);
create unique index departments_name_unique on public.departments (lower(name));

create table public.admins (
  email         text primary key check (email = lower(email) and email ~ '^[^\s@]+@[^\s@]+\.[a-z]{2,}$'),
  role          text not null check (role in ('key','dept')),
  department_id uuid references public.departments(id) on delete restrict,
  created_at    timestamptz not null default now(),
  check ((role = 'dept') = (department_id is not null))
);
create index admins_department_idx on public.admins (department_id);

create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text not null,
  name       text not null check (char_length(name) between 1 and 40),
  surname    text not null check (char_length(surname) between 1 and 40),
  grade      text not null check (grade = any (private.learner_grades() || array['Nie ''n leerder nie'])),
  gender     text check (gender in ('Seun','Meisie')),
  created_at timestamptz not null default now(),
  -- learners must say boy/girl (events can be for one of them only)
  check (not (grade = any (private.learner_grades())) or gender is not null)
);
create unique index profiles_email_unique on public.profiles (lower(email));

create table public.events (
  id                     bigint generated always as identity primary key,
  title                  text not null check (char_length(title) between 3 and 80),
  department_id          uuid not null references public.departments(id) on delete restrict,
  date                   date not null,
  start_time             time not null,
  end_time               time not null,
  venue                  text not null default '' check (char_length(venue) <= 80),
  description            text not null default '' check (char_length(description) <= 600),
  ticket_url             text check (ticket_url ~ '^https?://' and char_length(ticket_url) <= 500),
  lat                    double precision not null check (lat between -90 and 90),
  lng                    double precision not null check (lng between -180 and 180),
  radius                 integer not null check (radius between 25 and 1000),
  address                text not null default '' check (char_length(address) <= 200),
  audience_grades        text[] not null default '{}' check (audience_grades <@ private.learner_grades()),
  audience_gender        text not null default 'all' check (audience_gender in ('all','Seun','Meisie')),
  audience_learners_only boolean not null default false,
  created_by             uuid default auth.uid() references auth.users(id) on delete set null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  check (end_time - start_time >= interval '15 minutes')
);
create index events_date_idx on public.events (date);
create index events_department_idx on public.events (department_id);
create index events_created_by_idx on public.events (created_by);
create unique index events_no_duplicates on public.events (department_id, lower(title), date, start_time);

-- One secret per event, used to sign QR codes. In the private schema: no API access.
create table private.event_secrets (
  event_id bigint primary key references public.events(id) on delete cascade,
  secret   bytea not null default extensions.gen_random_bytes(16)
);

create table public.supports (                  -- "Ek ondersteun"
  event_id   bigint not null references public.events(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index supports_user_idx on public.supports (user_id);

create table public.checkins (                  -- "Meld aan" (GPS or QR)
  id          bigint generated always as identity primary key,
  event_id    bigint not null references public.events(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  scanned_at  timestamptz not null,
  received_at timestamptz not null default now(),
  lat         double precision,
  lng         double precision,
  accuracy    double precision,
  distance_m  integer,
  method      text not null check (method in ('gps','qr-live','qr-print')),
  device_id   text check (char_length(device_id) <= 64),
  flags       text[] not null default '{}',
  unique (event_id, user_id)
);
create index checkins_user_idx on public.checkins (user_id);

-- ---------------------------------------------------------------- helpers
-- All stable + security definer so policies can use them without recursion.
create or replace function private.my_email() returns text
language sql stable set search_path = '' as
$$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function private.is_key_admin() returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.admins a where a.email = private.my_email() and a.role = 'key') $$;

create or replace function private.can_admin(dept uuid) returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.admins a
                  where a.email = private.my_email()
                    and (a.role = 'key' or a.department_id = dept)) $$;

-- Does the signed-in user fit an event's audience? Unknown grade/gender never fits a rule that needs it.
create or replace function private.fits_audience(grades text[], gender text, learners_only boolean, uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as
$$
  -- Parameters are qualified with the function name: in a SQL function an
  -- unqualified name matches a column (p.gender) before a parameter.
  select case
    when coalesce(array_length(fits_audience.grades, 1), 0) = 0 and fits_audience.gender = 'all' and not fits_audience.learners_only then true
    else exists (
      select 1 from public.profiles p
      where p.id = fits_audience.uid
        and (not (fits_audience.learners_only or coalesce(array_length(fits_audience.grades, 1), 0) > 0) or p.grade = any (private.learner_grades()))
        and (coalesce(array_length(fits_audience.grades, 1), 0) = 0 or p.grade = any (fits_audience.grades))
        and (fits_audience.gender = 'all' or p.gender = fits_audience.gender))
  end
$$;

grant usage on schema private to authenticated;
grant execute on function private.my_email(), private.is_key_admin(), private.can_admin(uuid),
                          private.fits_audience(text[], text, boolean, uuid), private.learner_grades() to authenticated;

-- ---------------------------------------------------------------- triggers
-- New user from the sign-up form: the profile comes from the metadata sent
-- with signInWithOtp. A bad profile stops the sign-up (the app checks first).
-- Users made another way (e.g. in the dashboard) have no metadata: they get
-- no profile here and the app asks them to complete it after signing in.
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as
$$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(m ->> 'name', '') = '' then return new; end if;
  insert into public.profiles (id, email, name, surname, grade, gender)
  values (new.id, lower(new.email),
          btrim(m ->> 'name'), btrim(m ->> 'surname'), m ->> 'grade',
          case when (m ->> 'grade') = any (private.learner_grades()) then nullif(m ->> 'gender', '') else null end);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

create or replace function private.new_event_secret() returns trigger
language plpgsql security definer set search_path = '' as
$$ begin insert into private.event_secrets (event_id) values (new.id); return new; end $$;
create trigger events_secret after insert on public.events
  for each row execute function private.new_event_secret();

create or replace function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as
$$ begin new.updated_at := now(); return new; end $$;
create trigger events_touch before update on public.events
  for each row execute function private.touch_updated_at();

-- Never remove the last Hoof-admin.
create or replace function private.keep_a_key_admin() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if old.role = 'key' and (tg_op = 'DELETE' or new.role <> 'key')
     and (select count(*) from public.admins where role = 'key') <= 1 then
    raise exception 'last_key_admin' using hint = 'Daar moet altyd minstens een hoof-admin wees.';
  end if;
  return coalesce(new, old);
end $$;
create trigger admins_keep_key before update or delete on public.admins
  for each row execute function private.keep_a_key_admin();

-- ---------------------------------------------------------------- row level security
alter table public.departments enable row level security;
alter table public.admins      enable row level security;
alter table public.profiles    enable row level security;
alter table public.events      enable row level security;
alter table public.supports    enable row level security;
alter table public.checkins    enable row level security;
alter table private.event_secrets enable row level security;   -- no policies: nobody via the API

-- departments: everyone signed in reads; Hoof-admin writes
create policy "departments: read" on public.departments for select to authenticated using (true);
create policy "departments: key admin insert" on public.departments for insert to authenticated with check ((select private.is_key_admin()));
create policy "departments: key admin update" on public.departments for update to authenticated using ((select private.is_key_admin())) with check ((select private.is_key_admin()));
create policy "departments: key admin delete" on public.departments for delete to authenticated using ((select private.is_key_admin()));

-- admins: you can see your own row (that's your role); Hoof-admin sees and manages all
create policy "admins: own row or key admin" on public.admins for select to authenticated
  using (email = (select private.my_email()) or (select private.is_key_admin()));
create policy "admins: key admin insert" on public.admins for insert to authenticated with check ((select private.is_key_admin()));
create policy "admins: key admin update" on public.admins for update to authenticated using ((select private.is_key_admin())) with check ((select private.is_key_admin()));
create policy "admins: key admin delete" on public.admins for delete to authenticated using ((select private.is_key_admin()));

-- profiles: your own only (admins see names through event_attendees())
create policy "profiles: own read" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "profiles: own insert" on public.profiles for insert to authenticated
  with check (id = (select auth.uid()) and lower(email) = (select private.my_email()));
create policy "profiles: own update" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- events: you see what you manage plus what's for you; admins write their own departments
create policy "events: visible" on public.events for select to authenticated
  using (private.can_admin(department_id) or private.fits_audience(audience_grades, audience_gender, audience_learners_only));
create policy "events: admin insert" on public.events for insert to authenticated with check (private.can_admin(department_id));
create policy "events: admin update" on public.events for update to authenticated
  using (private.can_admin(department_id)) with check (private.can_admin(department_id));
create policy "events: admin delete" on public.events for delete to authenticated using (private.can_admin(department_id));

-- supports: your own, only for events you can see
create policy "supports: own read" on public.supports for select to authenticated using (user_id = (select auth.uid()));
create policy "supports: own insert" on public.supports for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.events e where e.id = event_id));
create policy "supports: own delete" on public.supports for delete to authenticated using (user_id = (select auth.uid()));

-- checkins: read your own; written only by public.checkin()
create policy "checkins: own read" on public.checkins for select to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- API functions
-- Your role, for the app's tabs.
create or replace function public.my_role()
returns table (role text, department_id uuid)
language sql stable security definer set search_path = '' as
$$ select a.role, a.department_id from public.admins a where a.email = private.my_email() $$;

-- Is this e-mail registered? (Lets the sign-up form say "teken eerder in".)
create or replace function public.email_registered(p_email text) returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.profiles where lower(email) = lower(btrim(p_email))) $$;

-- QR signature: first 12 bytes of HMAC-SHA256, base64url — same format the app parses.
create or replace function private.qr_sig(p_event_id bigint, p_window text) returns text
language sql stable security definer set search_path = '' as
$$
  select rtrim(translate(encode(substring(extensions.hmac(convert_to(p_event_id || '.' || p_window, 'UTF8'), s.secret, 'sha256') from 1 for 12), 'base64'), '+/', '-_'), '=')
  from private.event_secrets s where s.event_id = p_event_id
$$;

-- Tokens for an admin's QR screen. Live: the next 20 thirty-second windows
-- (10 minutes, so a short network drop doesn't blank the screen). Print: one fixed token.
create or replace function public.qr_tokens(p_event_id bigint, p_mode text)
returns table (win bigint, token text)
language plpgsql stable security definer set search_path = '' as
$$
declare dept uuid; w0 bigint := floor(extract(epoch from now()) / 30)::bigint;
begin
  select e.department_id into dept from public.events e where e.id = p_event_id;
  if dept is null or not private.can_admin(dept) then raise exception 'not_allowed'; end if;
  if p_mode = 'print' then
    return query select null::bigint, p_event_id || '.p.' || private.qr_sig(p_event_id, 'p');
  else
    return query select w, p_event_id || '.' || w || '.' || private.qr_sig(p_event_id, w::text)
                 from generate_series(w0, w0 + 19) w;
  end if;
end $$;

-- Check in (GPS button or QR scan, possibly sent later from an offline queue).
-- Never trusts the phone: re-checks the QR signature, the audience, the time
-- window and the distance. Suspicious check-ins are stored WITH reasons
-- (flags) for an admin to review; invalid codes are rejected.
create or replace function public.checkin(
  p_event_id bigint, p_method text, p_token text, p_scanned_at timestamptz,
  p_lat double precision, p_lng double precision, p_accuracy double precision, p_device text)
returns jsonb language plpgsql volatile security definer set search_path = '' as
$$
declare
  uid uuid := auth.uid();
  e public.events%rowtype;
  flags text[] := '{}';
  dist integer;
  parts text[];
  scanned timestamptz := least(coalesce(p_scanned_at, now()), now());   -- no future times
  age bigint;
begin
  if uid is null then return jsonb_build_object('status','error','message','Teken eers in.'); end if;
  select * into e from public.events where id = p_event_id;
  if not found then return jsonb_build_object('status','error','message','Hierdie geleentheid bestaan nie meer nie.'); end if;
  if not (private.fits_audience(e.audience_grades, e.audience_gender, e.audience_learners_only, uid) or private.can_admin(e.department_id)) then
    return jsonb_build_object('status','error','message','Hierdie geleentheid is nie vir jou nie.');
  end if;
  if exists (select 1 from public.checkins c where c.event_id = e.id and c.user_id = uid) then
    return jsonb_build_object('status','ok','message','Jy is reeds aangemeld.');
  end if;
  if scanned < now() - interval '7 days' then
    return jsonb_build_object('status','error','message','Hierdie skandering is te oud om nog te tel.');
  end if;

  if p_method in ('qr-live','qr-print') then
    parts := string_to_array(coalesce(p_token, ''), '.');
    if array_length(parts, 1) <> 3 or parts[1] <> e.id::text
       or parts[3] is distinct from private.qr_sig(e.id, parts[2])
       or (p_method = 'qr-print') <> (parts[2] = 'p') then
      return jsonb_build_object('status','error','message','Hierdie QR-kode is ongeldig.');
    end if;
    if parts[2] <> 'p' then
      age := floor(extract(epoch from scanned) / 30)::bigint - parts[2]::bigint;
      if age > 2 or age < -1 then flags := array_append(flags, 'QR-kode was ouer as ''n minuut (moontlik aangestuur)'); end if;
    end if;
  elsif p_method <> 'gps' then
    return jsonb_build_object('status','error','message','Onbekende aanmeld-metode.');
  end if;

  if p_lat is null or p_lng is null then
    flags := array_append(flags, 'Geen ligging nie');
  else
    dist := round(2 * 6371000 * asin(sqrt(
              power(sin(radians(e.lat - p_lat) / 2), 2) +
              cos(radians(p_lat)) * cos(radians(e.lat)) * power(sin(radians(e.lng - p_lng) / 2), 2))));
    if dist > e.radius + least(coalesce(p_accuracy, 0), 100) then
      flags := array_append(flags, 'Ligging ' || case when dist < 1000 then dist || ' m' else replace(round(dist / 1000.0, 1)::text, '.', ',') || ' km' end || ' van die geleentheid af');
    end if;
  end if;

  insert into public.checkins (event_id, user_id, scanned_at, lat, lng, accuracy, distance_m, method, device_id, flags)
  values (e.id, uid, scanned, p_lat, p_lng, p_accuracy, dist, p_method, left(p_device, 64), flags)
  on conflict (event_id, user_id) do nothing;

  if array_length(flags, 1) > 0 then
    return jsonb_build_object('status','flagged','message','Ontvang. Ons kon nie bevestig dat jy by die geleentheid is nie — ''n admin sal dit nagaan.');
  end if;
  return jsonb_build_object('status','ok','message','Jy is aangemeld by ' || e.title || '!');
end $$;

-- Everyone for an event's Excel export: supporters and check-ins, with
-- "same phone" added to the flags. Admins of the event only.
create or replace function public.event_attendees(p_event_id bigint)
returns table (name text, surname text, grade text, gender text, email text,
               supports boolean, checked_in_at timestamptz, method text, distance_m integer, flags text[])
language plpgsql stable security definer set search_path = '' as
$$
#variable_conflict use_column
declare dept uuid;
begin
  select e.department_id into dept from public.events e where e.id = p_event_id;
  if dept is null or not private.can_admin(dept) then raise exception 'not_allowed'; end if;
  return query
  with c as (
    select ch.*, array(select 'Dieselfde foon as ' || p2.name || ' ' || p2.surname
                       from public.checkins o join public.profiles p2 on p2.id = o.user_id
                       where o.event_id = ch.event_id and o.device_id = ch.device_id and o.user_id <> ch.user_id) as dup
    from public.checkins ch where ch.event_id = p_event_id
  ), people as (
    select user_id from public.supports where event_id = p_event_id
    union select user_id from c
  )
  select p.name, p.surname, p.grade, p.gender, p.email,
         exists (select 1 from public.supports s where s.event_id = p_event_id and s.user_id = p.id),
         c.scanned_at, c.method, c.distance_m, coalesce(c.flags, '{}') || coalesce(c.dup, '{}')
  from people x join public.profiles p on p.id = x.user_id
  left join c on c.user_id = x.user_id
  order by p.surname, p.name;
end $$;

-- Counts for the admin screens (Skep list, event screen) in one call.
create or replace function public.admin_event_stats()
returns table (event_id bigint, supporters integer, checked_in integer, suspicious integer)
language sql stable security definer set search_path = '' as
$$
  select e.id,
         (select count(*) from public.supports s where s.event_id = e.id)::int,
         (select count(*) from public.checkins c where c.event_id = e.id and c.flags = '{}')::int,
         (select count(*) from public.checkins c where c.event_id = e.id and c.flags <> '{}')::int
  from public.events e where private.can_admin(e.department_id)
$$;

-- Only signed-in users may call the API functions.
revoke execute on function public.my_role(), public.email_registered(text), public.qr_tokens(bigint, text),
  public.checkin(bigint, text, text, timestamptz, double precision, double precision, double precision, text),
  public.event_attendees(bigint), public.admin_event_stats() from public, anon;
grant execute on function public.my_role(), public.qr_tokens(bigint, text),
  public.checkin(bigint, text, text, timestamptz, double precision, double precision, double precision, text),
  public.event_attendees(bigint), public.admin_event_stats() to authenticated;
-- The sign-up form asks before anyone is signed in.
grant execute on function public.email_registered(text) to anon, authenticated;
revoke execute on function private.qr_sig(bigint, text) from public, anon, authenticated;
