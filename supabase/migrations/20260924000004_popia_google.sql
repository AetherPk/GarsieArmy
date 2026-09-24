-- ============================================================================
-- POPIA consent + "Teken in met Google".
--
-- popia_accepted_at: when the person accepted the privacy notice. New
-- profiles can't be made without it. People who registered before this was
-- added (null) are asked once in the app.
--
-- Google sign-ups have no grade in their metadata, so the sign-up trigger
-- leaves them without a profile and the app asks for it ("Voltooi jou
-- profiel", with the consent box).
-- ============================================================================

alter table public.profiles add column popia_accepted_at timestamptz;

-- The time always comes from the server, and consent can't be undone by
-- editing the row (to withdraw, the account is deleted).
create or replace function private.stamp_popia() returns trigger
language plpgsql set search_path = '' as
$$
begin
  if tg_op = 'UPDATE' and old.popia_accepted_at is not null then
    new.popia_accepted_at := old.popia_accepted_at;
  elsif new.popia_accepted_at is not null then
    new.popia_accepted_at := now();
  end if;
  return new;
end $$;
create trigger stamp_popia before insert or update of popia_accepted_at on public.profiles
  for each row execute function private.stamp_popia();

drop policy "profiles: own insert" on public.profiles;
create policy "profiles: own insert" on public.profiles for insert to authenticated
  with check (id = (select auth.uid()) and lower(email) = (select private.my_email()) and popia_accepted_at is not null);

-- Sign-up from the app's own form only: it sends name, surname, grade and
-- popia = true. Anything else (Google, dashboard) gets no profile here.
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as
$$
declare m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  if coalesce(m ->> 'name', '') = '' or coalesce(m ->> 'surname', '') = '' or coalesce(m ->> 'grade', '') = ''
     or coalesce(m ->> 'popia', '') <> 'true' then
    return new;
  end if;
  insert into public.profiles (id, email, name, surname, grade, gender, popia_accepted_at)
  values (new.id, lower(new.email),
          btrim(m ->> 'name'), btrim(m ->> 'surname'), m ->> 'grade',
          case when (m ->> 'grade') = any (private.learner_grades()) then nullif(m ->> 'gender', '') else null end,
          now());
  return new;
end $$;
