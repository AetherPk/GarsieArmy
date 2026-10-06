-- The group policies looked at each other (groups -> group_members ->
-- groups), which Postgres refuses as recursion. Both checks now go through
-- small security-definer helpers instead.
create or replace function private.group_is_open(p_group uuid) returns boolean
language sql stable security definer set search_path = '' as
$$ select coalesce((select open from public.groups where id = p_group), false) $$;

create or replace function private.in_group(p_group uuid, uid uuid default auth.uid()) returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.group_members m where m.group_id = p_group and m.user_id = uid) $$;

grant execute on function private.group_is_open(uuid), private.in_group(uuid, uuid) to authenticated;

drop policy "groups: read" on public.groups;
create policy "groups: read" on public.groups for select to authenticated
  using (open or private.can_admin(department_id) or private.in_group(id));

drop policy "group_members: join" on public.group_members;
create policy "group_members: join" on public.group_members for insert to authenticated
  with check ((user_id = (select auth.uid()) and private.group_is_open(group_id))
              or private.can_admin(private.group_department(group_id)));
drop policy "group_members: leave" on public.group_members;
create policy "group_members: leave" on public.group_members for delete to authenticated
  using ((user_id = (select auth.uid()) and private.group_is_open(group_id))
         or private.can_admin(private.group_department(group_id)));
