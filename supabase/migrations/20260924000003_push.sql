-- ============================================================================
-- Push notifications (Web Push).
--
-- How it fits together:
--   1. A phone that says "yes" to notifications saves its push address with
--      save_push_subscription().
--   2. Triggers on events (new / changed / cancelled) and a job every minute
--      (reminders) put messages in private.push_queue. Only the database
--      decides who gets what.
--   3. The queue "kicks" the send-push Edge Function (pg_net). It takes
--      messages with push_claim(), sends them, and reports back with
--      push_done(). Phones that no longer exist are removed there.
--      Kicking it more than needed is harmless: it only empties the queue.
--
-- The VAPID keys (the server's identity for Web Push) live in Supabase Vault,
-- NOT in this file: vapid_public_key, vapid_private_key, vapid_subject.
-- ============================================================================

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- ---------------------------------------------------------------- tables
-- One row per phone/browser. Only the real push services are accepted, so
-- the send function can't be pointed at any other address.
create table public.push_subscriptions (
  endpoint   text primary key check (char_length(endpoint) <= 1000 and endpoint ~
               '^https://(fcm\.googleapis\.com|updates\.push\.services\.mozilla\.com|[a-z0-9.-]+\.push\.apple\.com|[a-z0-9.-]+\.notify\.windows\.com)/'),
  user_id    uuid not null references auth.users(id) on delete cascade,
  p256dh     text not null check (char_length(p256dh) <= 200),
  auth       text not null check (char_length(auth) <= 100),
  created_at timestamptz not null default now()
);
create index on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
create policy "push_subscriptions: own read" on public.push_subscriptions for select to authenticated
  using (user_id = (select auth.uid()));
-- Writes go through save_push_subscription / remove_push_subscription.

-- "Also tell me about new events" (reminders and changes always come).
alter table public.profiles add column notify_new boolean not null default true;

create table private.push_queue (
  id         bigint generated always as identity primary key,
  endpoint   text not null,
  payload    jsonb not null,
  attempts   integer not null default 0,
  claimed_at timestamptz,
  created_at timestamptz not null default now()
);
create index on private.push_queue (claimed_at nulls first, id);

-- Events that already had their reminder, so it goes out once.
create table private.push_reminded (
  event_id bigint primary key references public.events(id) on delete cascade,
  sent_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------- helpers
-- Event times are school time (South Africa).
create or replace function private.event_starts(d date, t time) returns timestamptz
language sql immutable set search_path = '' as
$$ select (d + t) at time zone 'Africa/Johannesburg' $$;

-- "Sa 12 Sep om 08:00"
create or replace function private.af_when(d date, t time) returns text
language sql immutable set search_path = '' as
$$
  select (array['So','Ma','Di','Wo','Do','Vr','Sa'])[extract(dow from d)::int + 1] || ' ' ||
         extract(day from d)::int || ' ' ||
         (array['Jan','Feb','Mrt','Apr','Mei','Jun','Jul','Aug','Sep','Okt','Nov','Des'])[extract(month from d)::int] ||
         ' om ' || to_char(t, 'HH24:MI')
$$;

create or replace function private.push_payload(p_event_id bigint, p_title text, p_body text) returns jsonb
language sql immutable set search_path = '' as
$$
  select jsonb_build_object('title', p_title, 'body', p_body,
                            'url', 'garsie-army-prototype.html#geleentheid=' || p_event_id,
                            'tag', 'event-' || p_event_id)
$$;

-- Wake the send function. pg_net sends it after the transaction commits.
create or replace function private.push_kick() returns void
language plpgsql security definer set search_path = '' as
$$
begin
  perform net.http_post(
    url := 'https://ucecetiqnonnoaojlxrh.supabase.co/functions/v1/send-push',
    body := '{}'::jsonb,
    headers := '{"Content-Type":"application/json"}'::jsonb,
    timeout_milliseconds := 5000);
end
$$;

-- Queue one message for every phone of the given people.
create or replace function private.push_to(p_users uuid[], p_payload jsonb) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  insert into private.push_queue (endpoint, payload)
  select s.endpoint, p_payload from public.push_subscriptions s where s.user_id = any (p_users);
  if found then perform private.push_kick(); end if;
end
$$;

-- ---------------------------------------------------------------- triggers
-- New event: everyone it is meant for (the "Wie mag kom?" rules) who wants
-- new-event messages, except the admin who made it.
create or replace function private.push_event_created() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if private.event_starts(new.date, new.start_time) > now() then
    perform private.push_to(
      array(select p.id from public.profiles p
            where p.notify_new and p.id is distinct from new.created_by
              and private.fits_audience(new.audience_grades, new.audience_gender, new.audience_learners_only, p.id)
              and exists (select 1 from public.push_subscriptions s where s.user_id = p.id)),
      private.push_payload(new.id, 'Nuwe geleentheid: ' || new.title,
                           private.af_when(new.date, new.start_time) ||
                           case when new.venue <> '' then ' · ' || new.venue else '' end));
  end if;
  return null;
end
$$;

-- Moved (date, time or place) or renamed: everyone who pressed "Ek ondersteun".
create or replace function private.push_event_changed() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if (new.date, new.start_time, new.venue, new.title) is distinct from (old.date, old.start_time, old.venue, old.title)
     and private.event_starts(new.date, new.start_time) > now() then
    -- A new time means a new reminder.
    if (new.date, new.start_time) is distinct from (old.date, old.start_time) then
      delete from private.push_reminded where event_id = new.id;
    end if;
    perform private.push_to(
      array(select s.user_id from public.supports s where s.event_id = new.id),
      private.push_payload(new.id, 'Verandering: ' || new.title,
                           'Nou ' || private.af_when(new.date, new.start_time) ||
                           case when new.venue <> '' then ' · ' || new.venue else '' end));
  end if;
  return null;
end
$$;

-- Cancelled (deleted). BEFORE delete: the supporters are still there.
create or replace function private.push_event_cancelled() returns trigger
language plpgsql security definer set search_path = '' as
$$
begin
  if private.event_starts(old.date, old.start_time) > now() then
    perform private.push_to(
      array(select s.user_id from public.supports s where s.event_id = old.id),
      jsonb_build_object('title', 'Gekanselleer: ' || old.title,
                         'body', private.af_when(old.date, old.start_time) || ' gaan nie meer voort nie.',
                         'url', 'garsie-army-prototype.html',
                         'tag', 'event-' || old.id));
  end if;
  return old;
end
$$;

create trigger push_event_created   after insert on public.events for each row execute function private.push_event_created();
create trigger push_event_changed   after update on public.events for each row execute function private.push_event_changed();
create trigger push_event_cancelled before delete on public.events for each row execute function private.push_event_cancelled();

-- ---------------------------------------------------------------- every minute
-- Reminder about an hour before, to supporters. Also re-kicks the sender if
-- anything is still waiting (e.g. a send that failed).
create or replace function private.push_tick() returns void
language plpgsql security definer set search_path = '' as
$$
declare e record;
begin
  for e in
    insert into private.push_reminded (event_id)
    select ev.id from public.events ev
    where private.event_starts(ev.date, ev.start_time) between now() and now() + interval '60 minutes'
    on conflict do nothing
    returning event_id
  loop
    perform private.push_to(
      array(select s.user_id from public.supports s where s.event_id = e.event_id),
      (select private.push_payload(ev.id, 'Begin binnekort: ' || ev.title,
                                   'Vandag om ' || to_char(ev.start_time, 'HH24:MI') ||
                                   case when ev.venue <> '' then ' · ' || ev.venue else '' end)
       from public.events ev where ev.id = e.event_id));
  end loop;

  -- Give up on messages that failed three times or are a day old.
  delete from private.push_queue where attempts >= 3 or created_at < now() - interval '1 day';
  if exists (select 1 from private.push_queue where claimed_at is null or claimed_at < now() - interval '2 minutes') then
    perform private.push_kick();
  end if;
end
$$;

select cron.schedule('push-tick', '* * * * *', 'select private.push_tick()');

-- ---------------------------------------------------------------- app API
-- Save this phone for the signed-in person. A shared phone moves to whoever
-- signed in last.
create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.push_subscriptions (endpoint, user_id, p256dh, auth)
  values (p_endpoint, auth.uid(), p_p256dh, p_auth)
  on conflict (endpoint) do update
    set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
  -- At most 10 phones per person.
  delete from public.push_subscriptions
  where user_id = auth.uid() and endpoint in (
    select endpoint from public.push_subscriptions where user_id = auth.uid()
    order by created_at desc offset 10);
end
$$;

create or replace function public.remove_push_subscription(p_endpoint text) returns void
language sql security definer set search_path = '' as
$$ delete from public.push_subscriptions where endpoint = p_endpoint and user_id = auth.uid() $$;

-- "Stuur 'n toets": a message to your own phones only.
create or replace function public.push_test() returns integer
language plpgsql security definer set search_path = '' as
$$
declare n integer;
begin
  select count(*) into n from public.push_subscriptions where user_id = auth.uid();
  if n > 0 then
    perform private.push_to(array[auth.uid()],
      jsonb_build_object('title', 'Garsie Army', 'body', 'Kennisgewings werk op hierdie foon.',
                         'url', 'garsie-army-prototype.html', 'tag', 'test'));
  end if;
  return n;
end
$$;

-- ---------------------------------------------------------------- send function API
-- Only the send-push Edge Function (service role) may call these.
create or replace function public.push_config() returns table (public_key text, private_key text, subject text)
language sql stable security definer set search_path = '' as
$$
  select (select decrypted_secret from vault.decrypted_secrets where name = 'vapid_public_key'),
         (select decrypted_secret from vault.decrypted_secrets where name = 'vapid_private_key'),
         (select decrypted_secret from vault.decrypted_secrets where name = 'vapid_subject')
$$;

create or replace function public.push_claim(p_limit integer default 500)
returns table (id bigint, endpoint text, p256dh text, auth text, payload jsonb)
language plpgsql security definer set search_path = '' as
$$
#variable_conflict use_column
begin
  -- Messages for phones that were removed meanwhile.
  delete from private.push_queue q
  where not exists (select 1 from public.push_subscriptions s where s.endpoint = q.endpoint);

  return query
  with c as (
    select q.id from private.push_queue q
    where q.claimed_at is null or q.claimed_at < now() - interval '2 minutes'
    order by q.id
    limit least(greatest(p_limit, 1), 1000)
    for update skip locked)
  update private.push_queue q
     set claimed_at = now(), attempts = q.attempts + 1
    from c, public.push_subscriptions s
   where q.id = c.id and s.endpoint = q.endpoint
  returning q.id, q.endpoint, s.p256dh, s.auth, q.payload;
end
$$;

-- p_sent: delivered (remove from queue). p_gone: the phone unsubscribed or
-- the app was removed (remove the phone). Anything else is retried.
create or replace function public.push_done(p_sent bigint[], p_gone text[]) returns void
language plpgsql security definer set search_path = '' as
$$
begin
  delete from private.push_queue where id = any (p_sent);
  delete from public.push_subscriptions where endpoint = any (p_gone);
  delete from private.push_queue where endpoint = any (p_gone);
end
$$;

revoke execute on function public.save_push_subscription(text, text, text), public.remove_push_subscription(text),
                           public.push_test(), public.push_config(), public.push_claim(integer), public.push_done(bigint[], text[])
  from public, anon;
grant execute on function public.save_push_subscription(text, text, text), public.remove_push_subscription(text),
                          public.push_test() to authenticated;
revoke execute on function public.push_config(), public.push_claim(integer), public.push_done(bigint[], text[]) from authenticated;
grant execute on function public.push_config(), public.push_claim(integer), public.push_done(bigint[], text[]) to service_role;
revoke execute on function private.push_kick(), private.push_to(uuid[], jsonb), private.push_tick() from public, anon, authenticated;
