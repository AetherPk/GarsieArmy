-- Afrikaans fixes in two server messages (language review, October 2026):
-- "aanmeldmetode" is one word; the role is always written "Hoof-admin".
-- The init migration already has the corrected text for new databases.
do $$
declare def text;
begin
  def := pg_get_functiondef('public.checkin(bigint,text,text,timestamptz,double precision,double precision,double precision,text)'::regprocedure);
  execute replace(def, 'Onbekende aanmeld-metode.', 'Onbekende aanmeldmetode.');
  def := pg_get_functiondef('private.keep_a_key_admin()'::regprocedure);
  execute replace(def, 'minstens een hoof-admin wees', 'minstens een Hoof-admin wees');
end $$;
