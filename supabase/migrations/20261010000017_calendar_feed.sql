-- "Sit my besprekings in my kalender": a private calendar feed per person.
-- Switching it on makes a secret token; the phone's calendar (Apple, Google,
-- Outlook) subscribes to the calendar function with it and keeps the events
-- the person booked up to date by itself (moved, renamed, cancelled).
-- Switching it off deletes the token: the feed then comes back empty, so the
-- events disappear from the calendar at its next refresh.

create table public.calendar_feeds (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  token      text not null unique default encode(extensions.gen_random_bytes(18), 'hex'),
  created_at timestamptz not null default now()
);
alter table public.calendar_feeds enable row level security;
create policy "calendar_feeds: own read" on public.calendar_feeds for select to authenticated
  using (user_id = (select auth.uid()));

-- On: returns your token (the same one if it already exists).
create or replace function public.calendar_feed_on() returns text
language plpgsql volatile security definer set search_path = '' as
$$
declare t text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.calendar_feeds (user_id) values (auth.uid()) on conflict (user_id) do nothing;
  select token into t from public.calendar_feeds where user_id = auth.uid();
  return t;
end $$;

-- Off: the old link stops showing anything.
create or replace function public.calendar_feed_off() returns void
language sql volatile security definer set search_path = '' as
$$ delete from public.calendar_feeds where user_id = auth.uid() $$;

-- For the calendar function (no sign-in: the calendar app only has the link).
-- An unknown token simply gives no events.
create or replace function public.calendar_feed_events(p_token text)
returns table (id bigint, title text, starts timestamptz, ends timestamptz, venue text, address text,
               description text, department text, updated_at timestamptz)
language sql stable security definer set search_path = '' as
$$
  select e.id, e.title, private.event_starts(e.date, e.start_time), private.event_starts(e.date, e.end_time),
         e.venue, e.address, e.description, d.name, e.updated_at
  from public.calendar_feeds f
  join public.supports s on s.user_id = f.user_id
  join public.events e on e.id = s.event_id
  join public.departments d on d.id = e.department_id
  where f.token = p_token and char_length(p_token) >= 32
    and e.date >= (now() - interval '60 days')::date
  order by e.date, e.start_time
$$;

revoke execute on function public.calendar_feed_on(), public.calendar_feed_off() from public, anon;
grant execute on function public.calendar_feed_on(), public.calendar_feed_off() to authenticated;
revoke execute on function public.calendar_feed_events(text) from public;
grant execute on function public.calendar_feed_events(text) to anon, authenticated;
