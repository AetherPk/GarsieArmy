-- The non-learner choice is now "Personeel" (staff), the school's choice.
-- Matrieks no longer stay on: on 1 January their accounts are deleted.

alter table public.profiles drop constraint profiles_grade_check;
update public.profiles set grade = 'Personeel' where grade = 'Alumni';
alter table public.profiles add constraint profiles_grade_check
  check (grade = any (private.learner_grades() || array['Personeel']));

-- Phones that still run the previous version of the app may send the old
-- value for a short while: turn it into Personeel.
drop trigger if exists old_grade_to_alumni on public.profiles;
drop function if exists private.old_grade_to_alumni();
create or replace function private.old_grade_to_personeel() returns trigger
language plpgsql set search_path = '' as
$$
begin
  if new.grade in ('Alumni', 'Nie ''n leerder nie') then new.grade := 'Personeel'; end if;
  return new;
end $$;
create trigger old_grade_to_personeel before insert or update of grade on public.profiles
  for each row execute function private.old_grade_to_personeel();

-- 1 January: Graad 12 accounts are deleted (admins stay, as Personeel),
-- then everyone else goes up one grade.
create or replace function private.promote_grades() returns void
language plpgsql security definer set search_path = '' as
$$
begin
  update public.profiles p set grade = 'Personeel'
  where p.grade = 'Graad 12' and lower(p.email) in (select a.email from public.admins a);
  delete from auth.users u
  using public.profiles p
  where p.id = u.id and p.grade = 'Graad 12';
  update public.profiles set grade = case grade
      when 'Graad 8'  then 'Graad 9'
      when 'Graad 9'  then 'Graad 10'
      when 'Graad 10' then 'Graad 11'
      when 'Graad 11' then 'Graad 12'
    end
  where grade in ('Graad 8','Graad 9','Graad 10','Graad 11');
end $$;
