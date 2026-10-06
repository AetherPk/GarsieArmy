-- ============================================================================
-- Grades: locked for learners, moved up every year automatically.
--
-- Some events are only for certain grades (or only boys / only girls), so a
-- learner must not be able to change their own grade or gender to see
-- them. Only a Hoof-admin can change it (admin_set_learner, from Bestuur).
-- Every learner is treated as passing: on 1 January Graad 8 → 9 … 11 → 12,
-- and Graad 12 → Alumni.
-- ============================================================================

create or replace function private.lock_grade() returns trigger
language plpgsql set search_path = '' as
$$
begin
  -- auth.uid() is empty for the yearly job and other server-side work.
  if (new.grade, new.gender) is distinct from (old.grade, old.gender)
     and auth.uid() is not null and not private.is_key_admin() then
    raise exception 'grade_locked';
  end if;
  return new;
end $$;
create trigger lock_grade before update of grade, gender on public.profiles
  for each row execute function private.lock_grade();

-- Hoof-admin: change one learner's grade and/or gender by e-mail address.
create or replace function public.admin_set_learner(p_email text, p_grade text, p_gender text)
returns boolean language plpgsql security definer set search_path = '' as
$$
begin
  if not private.is_key_admin() then raise exception 'not allowed'; end if;
  update public.profiles
     set grade = p_grade,
         gender = case when p_grade = any (private.learner_grades()) then nullif(p_gender, '') else null end
   where email = lower(btrim(p_email));
  return found;
end $$;
revoke execute on function public.admin_set_learner(text, text, text) from public, anon;
grant execute on function public.admin_set_learner(text, text, text) to authenticated;

-- 1 January, 00:05 South African time (22:05 UTC on 31 December).
create or replace function private.promote_grades() returns void
language sql security definer set search_path = '' as
$$
  update public.profiles set grade = case grade
      when 'Graad 8'  then 'Graad 9'
      when 'Graad 9'  then 'Graad 10'
      when 'Graad 10' then 'Graad 11'
      when 'Graad 11' then 'Graad 12'
      when 'Graad 12' then 'Alumni'
    end
  where grade in ('Graad 8','Graad 9','Graad 10','Graad 11','Graad 12');
$$;
revoke execute on function private.promote_grades() from public, anon, authenticated;
select cron.schedule('promote-grades', '5 22 31 12 *', 'select private.promote_grades()');
