-- ============================================================================
-- Data kept at most 5 years (the school's POPIA decision), and
-- "Skrap my rekening" in the app.
-- ============================================================================

-- Every night at 02:00 (UTC): delete
--   - events that ended more than 5 years ago (their supports and check-ins
--     go with them: on delete cascade)
--   - accounts not signed in to for 5 years (profile, supports, check-ins
--     and push subscriptions go with them)
create or replace function private.delete_old_data() returns void
language plpgsql security definer set search_path = '' as
$$
begin
  delete from public.events where date < (now() - interval '5 years')::date;
  delete from auth.users
  where coalesce(last_sign_in_at, created_at) < now() - interval '5 years'
    and lower(email) not in (select a.email from public.admins a);   -- admins are removed in Bestuur
end $$;
revoke execute on function private.delete_old_data() from public, anon, authenticated;
select cron.schedule('delete-old-data', '0 2 * * *', 'select private.delete_old_data()');

-- The signed-in person deletes their own account and everything linked to
-- it (profile, supports, check-ins, phones for notifications). Events they
-- made stay (created_by becomes empty). An admin keeps the admin row in
-- Bestuur until a key admin removes it; the last key admin can't delete
-- themselves (someone must be able to run the app).
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as
$$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in'; end if;
  if exists (select 1 from public.admins a where a.email = private.my_email() and a.role = 'key')
     and (select count(*) from public.admins where role = 'key') = 1 then
    raise exception 'last_key_admin';
  end if;
  delete from auth.users where id = uid;
end $$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
