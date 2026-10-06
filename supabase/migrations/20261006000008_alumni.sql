-- "Nie 'n leerder nie" becomes "Alumni" (the school's choice).
-- Existing profiles are converted. A phone still running the old app may
-- send the old value for a short while: the trigger turns it into Alumni.
alter table public.profiles drop constraint profiles_grade_check;
update public.profiles set grade = 'Alumni' where grade = 'Nie ''n leerder nie';
alter table public.profiles add constraint profiles_grade_check
  check (grade = any (private.learner_grades() || array['Alumni']));

create or replace function private.old_grade_to_alumni() returns trigger
language plpgsql set search_path = '' as
$$
begin
  if new.grade = 'Nie ''n leerder nie' then new.grade := 'Alumni'; end if;
  return new;
end $$;
create trigger old_grade_to_alumni before insert or update of grade on public.profiles
  for each row execute function private.old_grade_to_alumni();
