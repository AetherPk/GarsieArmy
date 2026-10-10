-- 1. Being added to a group by an admin lands in your inbox (and as a push).
-- 2. Admins find people by name, surname or e-mail while typing (a search
--    dropdown), and add them to a group straight from the results.

alter table public.inbox drop constraint inbox_kind_check;
alter table public.inbox add constraint inbox_kind_check check (kind in ('new','changed','cancelled','group'));

create or replace function private.is_any_admin() returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.admins a where a.email = private.my_email()) $$;
grant execute on function private.is_any_admin() to authenticated;

-- Add people to a group and tell the ones who are new in it.
create or replace function private.group_add_users(p_group uuid, p_users uuid[]) returns integer
language plpgsql security definer set search_path = '' as
$$
declare
  g public.groups%rowtype;
  fresh uuid[];
begin
  select * into g from public.groups where id = p_group;
  with ins as (insert into public.group_members (group_id, user_id)
               select p_group, u from unnest(p_users) u
               where exists (select 1 from public.profiles p where p.id = u)
               on conflict do nothing returning user_id)
  select coalesce(array_agg(user_id), '{}') into fresh from ins;
  if cardinality(fresh) > 0 then
    perform private.notify(fresh, 'group', null,
      jsonb_build_object('title', 'Jy is bygevoeg by ' || g.name,
                         'body', (select d.name from public.departments d where d.id = g.department_id) ||
                                 ' · Jy hoor nou van geleenthede vir hierdie groep.',
                         'url', 'garsie-army-prototype.html',
                         'tag', 'group-' || g.id));
  end if;
  return cardinality(fresh);
end $$;
revoke execute on function private.group_add_users(uuid, uuid[]) from public, anon, authenticated;

create or replace function public.admin_group_add(p_group uuid, p_emails text[]) returns jsonb
language plpgsql volatile security definer set search_path = '' as
$$
declare n integer;
begin
  if not private.can_admin(private.group_department(p_group)) then raise exception 'not_allowed'; end if;
  n := private.group_add_users(p_group, array(select p.id from public.profiles p
         where lower(p.email) = any (select lower(btrim(e)) from unnest(p_emails) e)));
  return jsonb_build_object('added', n, 'unknown', to_jsonb(private.unknown_emails(p_emails)));
end $$;

create or replace function public.admin_group_add_users(p_group uuid, p_users uuid[]) returns integer
language plpgsql volatile security definer set search_path = '' as
$$
begin
  if not private.can_admin(private.group_department(p_group)) then raise exception 'not_allowed'; end if;
  return private.group_add_users(p_group, p_users);
end $$;

-- Every word must match the start of the name, the surname or the e-mail.
create or replace function public.admin_search_people(p_query text)
returns table (user_id uuid, name text, surname text, grade text, gender text, email text)
language plpgsql stable security definer set search_path = '' as
$$
declare words text[] := array(select lower(w) from regexp_split_to_table(btrim(coalesce(p_query, '')), '\s+') w where w <> '');
begin
  if not private.is_any_admin() then raise exception 'not_allowed'; end if;
  if cardinality(words) = 0 or char_length(btrim(p_query)) < 2 then return; end if;
  return query
    select p.id, p.name, p.surname, p.grade, p.gender, p.email from public.profiles p
    where (select bool_and(lower(p.name) like w || '%' or lower(p.surname) like w || '%'
                           or lower(p.name || ' ' || p.surname) like w || '%' or lower(p.email) like w || '%')
           from unnest(words) w)
    order by p.surname, p.name limit 8;
end $$;

revoke execute on function public.admin_group_add_users(uuid, uuid[]), public.admin_search_people(text) from public, anon;
grant execute on function public.admin_group_add_users(uuid, uuid[]), public.admin_search_people(text) to authenticated;
