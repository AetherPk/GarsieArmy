-- Learners can't change their name either: grade, gender, name and surname
-- are all set at registration and changed only by a Hoof-admin
-- (Instellings → Addisionele funksies).

create or replace function private.lock_grade() returns trigger
language plpgsql set search_path = '' as
$$
begin
  if (new.grade, new.gender, new.name, new.surname) is distinct from (old.grade, old.gender, old.name, old.surname)
     and auth.uid() is not null and not private.is_key_admin() then
    raise exception 'grade_locked';
  end if;
  return new;
end $$;
drop trigger lock_grade on public.profiles;
create trigger lock_grade before update of grade, gender, name, surname on public.profiles
  for each row execute function private.lock_grade();

-- Hoof-admin: look a learner up by e-mail address.
create or replace function public.admin_get_learner(p_email text)
returns table (name text, surname text, grade text, gender text)
language plpgsql stable security definer set search_path = '' as
$$
begin
  if not private.is_key_admin() then raise exception 'not allowed'; end if;
  return query select p.name, p.surname, p.grade, p.gender from public.profiles p where p.email = lower(btrim(p_email));
end $$;

-- Hoof-admin: change a learner's name, grade and gender.
drop function public.admin_set_learner(text, text, text);
create or replace function public.admin_set_learner(p_email text, p_name text, p_surname text, p_grade text, p_gender text)
returns boolean language plpgsql security definer set search_path = '' as
$$
begin
  if not private.is_key_admin() then raise exception 'not allowed'; end if;
  update public.profiles
     set name = btrim(p_name), surname = btrim(p_surname), grade = p_grade,
         gender = case when p_grade = any (private.learner_grades()) then nullif(p_gender, '') else null end
   where email = lower(btrim(p_email));
  return found;
end $$;

revoke execute on function public.admin_get_learner(text), public.admin_set_learner(text, text, text, text, text) from public, anon;
grant execute on function public.admin_get_learner(text), public.admin_set_learner(text, text, text, text, text) to authenticated;
