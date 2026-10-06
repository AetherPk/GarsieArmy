-- ============================================================================
-- Subafdelings (groups), following, invitations and the inbox.
--
--   groups              Each department's admins make subafdelings (Rugby,
--                       Koor, Eerste span ...). An OPEN group: anyone can join
--                       or leave it (that is "follow"). A PRIVATE group: only
--                       the department's admins add or remove people.
--   department_unfollows
--                       Everyone follows every department from the start;
--                       this keeps who switched one off.
--   events.group_id     The subafdeling an event belongs to (optional).
--   events.invite_only  Only invited people (and admins) see the event.
--   invitations         Admin invites people; they accept or decline.
--                       An invitation always gives access to the event.
--                       Accepting books ("bespreek") the event.
--   inbox               What was sent to someone (new event, change,
--                       cancellation), so it can be read in the app even
--                       with notifications off. Invitations show from their
--                       own table.
--
-- New events no longer notify everyone automatically: the admin chooses who
-- (announce_event, called by the app right after creating it). Nobody but
-- admins can see who was notified, invited or is in a group.
-- ============================================================================

-- ---------------------------------------------------------------- tables
create table public.groups (
  id            uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments(id) on delete cascade,
  name          text not null check (char_length(name) between 2 and 40),
  open          boolean not null default true,
  created_at    timestamptz not null default now()
);
create unique index groups_name_unique on public.groups (department_id, lower(name));

create table public.group_members (
  group_id   uuid not null references public.groups(id) on delete cascade,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user_idx on public.group_members (user_id);

create table public.department_unfollows (
  department_id uuid not null references public.departments(id) on delete cascade,
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  primary key (department_id, user_id)
);
create index department_unfollows_user_idx on public.department_unfollows (user_id);

-- Whoever had "new events" switched off now follows nothing (same effect).
insert into public.department_unfollows (department_id, user_id)
select d.id, p.id from public.profiles p cross join public.departments d where not p.notify_new
on conflict do nothing;

alter table public.events add column group_id uuid references public.groups(id) on delete set null;
alter table public.events add column invite_only boolean not null default false;
create index events_group_idx on public.events (group_id);

create table public.invitations (
  event_id    bigint not null references public.events(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending','accepted','declined')),
  invited_at  timestamptz not null default now(),
  answered_at timestamptz,
  primary key (event_id, user_id)
);
create index invitations_user_idx on public.invitations (user_id);

create table public.inbox (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  event_id   bigint references public.events(id) on delete set null,
  kind       text not null check (kind in ('new','changed','cancelled')),
  title      text not null,
  body       text not null default '',
  created_at timestamptz not null default now(),
  read_at    timestamptz
);
create index inbox_user_idx on public.inbox (user_id, created_at desc);
create index inbox_event_idx on public.inbox (event_id);

-- ---------------------------------------------------------------- helpers
create or replace function private.is_invited(p_event bigint, uid uuid default auth.uid()) returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.invitations i where i.event_id = p_event and i.user_id = uid) $$;

-- May this person see the event (not counting admin rights)?
create or replace function private.can_see(p_event bigint, uid uuid) returns boolean
language sql stable security definer set search_path = '' as
$$
  select exists (select 1 from public.events e where e.id = p_event and
    (private.is_invited(e.id, uid) or
     (not e.invite_only and private.fits_audience(e.audience_grades, e.audience_gender, e.audience_learners_only, uid))))
$$;

create or replace function private.group_department(p_group uuid) returns uuid
language sql stable security definer set search_path = '' as
$$ select department_id from public.groups where id = p_group $$;

grant execute on function private.is_invited(bigint, uuid), private.can_see(bigint, uuid),
                          private.group_department(uuid) to authenticated;

-- An event's subafdeling must be in the event's own department.
create or replace function private.check_event_group() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if new.group_id is not null and private.group_department(new.group_id) is distinct from new.department_id then
    raise exception 'group_wrong_department';
  end if;
  return new;
end $$;
create trigger events_check_group before insert or update of group_id, department_id on public.events
  for each row execute function private.check_event_group();

-- Booking an event you were invited to counts as accepting.
create or replace function private.support_accepts_invite() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  update public.invitations set status = 'accepted', answered_at = now()
  where event_id = new.event_id and user_id = new.user_id and status <> 'accepted';
  return null;
end $$;
create trigger supports_accept_invite after insert on public.supports
  for each row execute function private.support_accepts_invite();

-- Inbox row + push for each person (push only to phones that have it on).
create or replace function private.notify(p_users uuid[], p_kind text, p_event bigint, p_payload jsonb) returns integer
language plpgsql security definer set search_path = '' as
$$
declare n integer;
begin
  insert into public.inbox (user_id, event_id, kind, title, body)
  select distinct u, p_event, p_kind, p_payload ->> 'title', coalesce(p_payload ->> 'body', '')
  from unnest(p_users) u where exists (select 1 from public.profiles p where p.id = u);
  get diagnostics n = row_count;
  perform private.push_to(p_users, p_payload);
  return n;
end $$;
revoke execute on function private.notify(uuid[], text, bigint, jsonb) from public, anon, authenticated;

-- Everyone picked by these rules (people with a profile).
create or replace function private.pick_people(p_grades text[], p_gender text, p_emails text[], p_groups uuid[])
returns uuid[] language sql stable security definer set search_path = '' as
$$
  select coalesce(array_agg(distinct x.id), '{}') from (
    select p.id from public.profiles p
    where coalesce(array_length(p_grades, 1), 0) > 0 and p.grade = any (p_grades)
      and (coalesce(p_gender, 'all') = 'all' or p.gender = p_gender)
    union
    select p.id from public.profiles p where lower(p.email) = any (select lower(btrim(e)) from unnest(p_emails) e)
    union
    select m.user_id from public.group_members m where m.group_id = any (p_groups)
  ) x
$$;
revoke execute on function private.pick_people(text[], text, text[], uuid[]) from public, anon, authenticated;

-- E-mail addresses in the list that belong to nobody.
create or replace function private.unknown_emails(p_emails text[]) returns text[]
language sql stable security definer set search_path = '' as
$$
  select coalesce(array_agg(distinct lower(btrim(e))), '{}') from unnest(p_emails) e
  where btrim(e) <> '' and not exists (select 1 from public.profiles p where lower(p.email) = lower(btrim(e)))
$$;
revoke execute on function private.unknown_emails(text[]) from public, anon, authenticated;

-- ---------------------------------------------------------------- who sees events
drop policy "events: visible" on public.events;
create policy "events: visible" on public.events for select to authenticated
  using (private.can_admin(department_id) or private.is_invited(id)
         or (not invite_only and private.fits_audience(audience_grades, audience_gender, audience_learners_only)));

-- Check-in: an invitation also gives access; an invite-only event needs one.
do $$
declare def text;
begin
  def := pg_get_functiondef('public.checkin(bigint,text,text,timestamptz,double precision,double precision,double precision,text)'::regprocedure);
  def := replace(def,
    'if not (private.fits_audience(e.audience_grades, e.audience_gender, e.audience_learners_only, uid) or private.can_admin(e.department_id)) then',
    'if not (private.can_see(e.id, uid) or private.can_admin(e.department_id)) then');
  if position('private.can_see(e.id, uid)' in def) = 0 then raise exception 'checkin audience line not found'; end if;
  execute def;
end $$;

-- ---------------------------------------------------------------- row level security
alter table public.groups               enable row level security;
alter table public.group_members        enable row level security;
alter table public.department_unfollows enable row level security;
alter table public.invitations          enable row level security;
alter table public.inbox                enable row level security;

-- groups: open ones for everyone; private ones for their admins and members
create policy "groups: read" on public.groups for select to authenticated
  using (open or private.can_admin(department_id)
         or exists (select 1 from public.group_members m where m.group_id = groups.id and m.user_id = (select auth.uid())));
create policy "groups: admin insert" on public.groups for insert to authenticated with check (private.can_admin(department_id));
create policy "groups: admin update" on public.groups for update to authenticated
  using (private.can_admin(department_id)) with check (private.can_admin(department_id));
create policy "groups: admin delete" on public.groups for delete to authenticated using (private.can_admin(department_id));

-- group_members: you see your own rows (admins use group_member_list);
-- join/leave yourself only in an open group; admins add/remove anyone
create policy "group_members: own read" on public.group_members for select to authenticated
  using (user_id = (select auth.uid()) or private.can_admin(private.group_department(group_id)));
create policy "group_members: join" on public.group_members for insert to authenticated
  with check ((user_id = (select auth.uid()) and exists (select 1 from public.groups g where g.id = group_id and g.open))
              or private.can_admin(private.group_department(group_id)));
create policy "group_members: leave" on public.group_members for delete to authenticated
  using ((user_id = (select auth.uid()) and exists (select 1 from public.groups g where g.id = group_id and g.open))
         or private.can_admin(private.group_department(group_id)));

-- department_unfollows: your own
create policy "department_unfollows: own read" on public.department_unfollows for select to authenticated
  using (user_id = (select auth.uid()));
create policy "department_unfollows: own insert" on public.department_unfollows for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "department_unfollows: own delete" on public.department_unfollows for delete to authenticated
  using (user_id = (select auth.uid()));

-- invitations: read your own; answered with answer_invitation(); made with invite_to_event()
create policy "invitations: own read" on public.invitations for select to authenticated
  using (user_id = (select auth.uid()));

-- inbox: your own; mark read with mark_inbox_read(); you may clear items
create policy "inbox: own read" on public.inbox for select to authenticated using (user_id = (select auth.uid()));
create policy "inbox: own delete" on public.inbox for delete to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- notifications
-- New events: the admin picks who (announce_event), so no automatic message.
drop trigger push_event_created on public.events;

-- Moved or renamed: everyone who booked. Also in their inbox.
create or replace function private.push_event_changed() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if (new.date, new.start_time, new.venue, new.title) is distinct from (old.date, old.start_time, old.venue, old.title)
     and private.event_starts(new.date, new.start_time) > now() then
    if (new.date, new.start_time) is distinct from (old.date, old.start_time) then
      delete from private.push_reminded where event_id = new.id;
    end if;
    perform private.notify(
      array(select s.user_id from public.supports s where s.event_id = new.id), 'changed', new.id,
      private.push_payload(new.id, 'Verandering: ' || new.title,
                           'Nou ' || private.af_when(new.date, new.start_time) ||
                           case when new.venue <> '' then ' · ' || new.venue else '' end));
  end if;
  return null;
end
$$;

-- Cancelled (deleted): everyone who booked. BEFORE delete: they are still there.
create or replace function private.push_event_cancelled() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if private.event_starts(old.date, old.start_time) > now() then
    perform private.notify(
      array(select s.user_id from public.supports s where s.event_id = old.id), 'cancelled', old.id,
      jsonb_build_object('title', 'Gekanselleer: ' || old.title,
                         'body', 'Die geleentheid op ' || private.af_when(old.date, old.start_time) || ' gaan nie meer voort nie.',
                         'url', 'garsie-army-prototype.html',
                         'tag', 'event-' || old.id));
  end if;
  return old;
end
$$;

-- ---------------------------------------------------------------- app API
-- After creating an event: tell the people the admin picked. Only people
-- who may see the event get it, never the admin who made it.
--   p_followers      everyone who follows the event's department
--   p_group_members  everyone in the event's subafdeling
--   p_grades/p_gender, p_emails, p_groups  extra people
create or replace function public.announce_event(p_event_id bigint, p_followers boolean, p_group_members boolean,
  p_grades text[], p_gender text, p_emails text[], p_groups uuid[])
returns jsonb language plpgsql volatile security definer set search_path = '' as
$$
declare
  e public.events%rowtype;
  people uuid[];
  n integer := 0;
begin
  select * into e from public.events where id = p_event_id;
  if not found or not private.can_admin(e.department_id) then raise exception 'not_allowed'; end if;
  if exists (select 1 from unnest(coalesce(p_groups, '{}')) g where private.group_department(g) is distinct from e.department_id) then
    raise exception 'not_allowed';
  end if;
  people := private.pick_people(p_grades, p_gender, p_emails, p_groups);
  if p_followers then
    people := people || array(select p.id from public.profiles p
      where not exists (select 1 from public.department_unfollows u where u.department_id = e.department_id and u.user_id = p.id));
  end if;
  if p_group_members and e.group_id is not null then
    people := people || array(select m.user_id from public.group_members m where m.group_id = e.group_id);
  end if;
  people := array(select distinct u from unnest(people) u
                  where u is distinct from auth.uid() and private.can_see(e.id, u));
  if private.event_starts(e.date, e.start_time) > now() and cardinality(people) > 0 then
    n := private.notify(people, 'new', e.id,
      private.push_payload(e.id, 'Nuwe geleentheid: ' || e.title,
                           private.af_when(e.date, e.start_time) ||
                           case when e.venue <> '' then ' · ' || e.venue else '' end));
  end if;
  return jsonb_build_object('sent', n, 'unknown', to_jsonb(private.unknown_emails(coalesce(p_emails, '{}'))));
end $$;

-- Invite people to an event. Each new invitee gets a notification; people
-- already invited are left as they are.
create or replace function public.invite_to_event(p_event_id bigint, p_grades text[], p_gender text, p_emails text[], p_groups uuid[])
returns jsonb language plpgsql volatile security definer set search_path = '' as
$$
declare
  e public.events%rowtype;
  fresh uuid[];
  total integer;
begin
  select * into e from public.events where id = p_event_id;
  if not found or not private.can_admin(e.department_id) then raise exception 'not_allowed'; end if;
  if exists (select 1 from unnest(coalesce(p_groups, '{}')) g where private.group_department(g) is distinct from e.department_id) then
    raise exception 'not_allowed';
  end if;
  with picked as (select unnest(private.pick_people(p_grades, p_gender, p_emails, p_groups)) as uid),
       ins as (insert into public.invitations (event_id, user_id)
               select e.id, uid from picked on conflict do nothing returning user_id)
  select coalesce(array_agg(user_id), '{}') into fresh from ins;
  total := cardinality(private.pick_people(p_grades, p_gender, p_emails, p_groups));
  if cardinality(fresh) > 0 then
    perform private.push_to(fresh,
      private.push_payload(e.id, 'Uitnodiging: ' || e.title,
                           private.af_when(e.date, e.start_time) || ' — tik om te aanvaar of te weier'));
  end if;
  return jsonb_build_object('invited', cardinality(fresh), 'already', total - cardinality(fresh),
                            'unknown', to_jsonb(private.unknown_emails(coalesce(p_emails, '{}'))));
end $$;

-- Accept (books the event) or decline (cancels the booking).
create or replace function public.answer_invitation(p_event_id bigint, p_accept boolean) returns void
language plpgsql volatile security definer set search_path = '' as
$$
begin
  update public.invitations set status = case when p_accept then 'accepted' else 'declined' end, answered_at = now()
  where event_id = p_event_id and user_id = auth.uid();
  if not found then raise exception 'not_allowed'; end if;
  if p_accept then
    insert into public.supports (event_id, user_id) values (p_event_id, auth.uid()) on conflict do nothing;
  else
    delete from public.supports where event_id = p_event_id and user_id = auth.uid();
  end if;
end $$;

create or replace function public.mark_inbox_read() returns void
language sql volatile security definer set search_path = '' as
$$ update public.inbox set read_at = now() where user_id = auth.uid() and read_at is null $$;

-- Admins: add people to a group by e-mail. Returns the unknown addresses.
create or replace function public.admin_group_add(p_group uuid, p_emails text[]) returns jsonb
language plpgsql volatile security definer set search_path = '' as
$$
declare n integer;
begin
  if not private.can_admin(private.group_department(p_group)) then raise exception 'not_allowed'; end if;
  insert into public.group_members (group_id, user_id)
  select p_group, p.id from public.profiles p where lower(p.email) = any (select lower(btrim(e)) from unnest(p_emails) e)
  on conflict do nothing;
  get diagnostics n = row_count;
  return jsonb_build_object('added', n, 'unknown', to_jsonb(private.unknown_emails(p_emails)));
end $$;

-- Admins: who is in a group (p_group), or who follows a department (p_department).
create or replace function public.admin_member_list(p_group uuid, p_department uuid)
returns table (user_id uuid, name text, surname text, grade text, gender text, email text)
language plpgsql stable security definer set search_path = '' as
$$
begin
  if p_group is not null then
    if not private.can_admin(private.group_department(p_group)) then raise exception 'not_allowed'; end if;
    return query select p.id, p.name, p.surname, p.grade, p.gender, p.email
      from public.group_members m join public.profiles p on p.id = m.user_id
      where m.group_id = p_group order by p.surname, p.name, p.id;
  else
    if not private.can_admin(p_department) then raise exception 'not_allowed'; end if;
    return query select p.id, p.name, p.surname, p.grade, p.gender, p.email
      from public.profiles p
      where not exists (select 1 from public.department_unfollows u where u.department_id = p_department and u.user_id = p.id)
      order by p.surname, p.name, p.id;
  end if;
end $$;

-- Admins: member counts (group_id null = followers of the department).
create or replace function public.admin_group_stats()
returns table (department_id uuid, group_id uuid, members integer)
language sql stable security definer set search_path = '' as
$$
  select d.id, null::uuid,
         ((select count(*) from public.profiles) -
          (select count(*) from public.department_unfollows u where u.department_id = d.id))::int
  from public.departments d where private.can_admin(d.id)
  union all
  select g.department_id, g.id, (select count(*) from public.group_members m where m.group_id = g.id)::int
  from public.groups g where private.can_admin(g.department_id)
$$;

-- The attendance export now also has invitations. Return type changes, so drop first.
drop function public.event_attendees(bigint);
create function public.event_attendees(p_event_id bigint)
returns table (name text, surname text, grade text, gender text, email text,
               supports boolean, checked_in_at timestamptz, method text, distance_m integer, flags text[], invitation text)
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
    union select user_id from public.invitations where event_id = p_event_id
  )
  select p.name, p.surname, p.grade, p.gender, p.email,
         exists (select 1 from public.supports s where s.event_id = p_event_id and s.user_id = p.id),
         c.scanned_at, c.method, c.distance_m, coalesce(c.flags, '{}') || coalesce(c.dup, '{}'),
         (select i.status from public.invitations i where i.event_id = p_event_id and i.user_id = p.id)
  from people x join public.profiles p on p.id = x.user_id
  left join c on c.user_id = x.user_id
  order by p.surname, p.name;
end $$;

drop function public.admin_event_stats();
create function public.admin_event_stats()
returns table (event_id bigint, supporters integer, checked_in integer, suspicious integer,
               invited integer, accepted integer, declined integer)
language sql stable security definer set search_path = '' as
$$
  select e.id,
         (select count(*) from public.supports s where s.event_id = e.id)::int,
         (select count(*) from public.checkins c where c.event_id = e.id and c.flags = '{}')::int,
         (select count(*) from public.checkins c where c.event_id = e.id and c.flags <> '{}')::int,
         (select count(*) from public.invitations i where i.event_id = e.id)::int,
         (select count(*) from public.invitations i where i.event_id = e.id and i.status = 'accepted')::int,
         (select count(*) from public.invitations i where i.event_id = e.id and i.status = 'declined')::int
  from public.events e where private.can_admin(e.department_id)
$$;

revoke execute on function public.announce_event(bigint, boolean, boolean, text[], text, text[], uuid[]),
  public.invite_to_event(bigint, text[], text, text[], uuid[]), public.answer_invitation(bigint, boolean),
  public.mark_inbox_read(), public.admin_group_add(uuid, text[]), public.admin_member_list(uuid, uuid),
  public.admin_group_stats(), public.event_attendees(bigint), public.admin_event_stats() from public, anon;
grant execute on function public.announce_event(bigint, boolean, boolean, text[], text, text[], uuid[]),
  public.invite_to_event(bigint, text[], text, text[], uuid[]), public.answer_invitation(bigint, boolean),
  public.mark_inbox_read(), public.admin_group_add(uuid, text[]), public.admin_member_list(uuid, uuid),
  public.admin_group_stats(), public.event_attendees(bigint), public.admin_event_stats() to authenticated;

-- ---------------------------------------------------------------- retention
-- Inbox messages are kept a year (events themselves follow the 5-year rule).
create or replace function private.delete_old_data() returns void
language plpgsql security definer set search_path = '' as
$$
begin
  delete from public.events where date < (now() - interval '5 years')::date;
  delete from public.inbox where created_at < now() - interval '1 year';
  delete from auth.users
  where coalesce(last_sign_in_at, created_at) < now() - interval '5 years'
    and lower(email) not in (select a.email from public.admins a);   -- admins are removed in Bestuur
end $$;
