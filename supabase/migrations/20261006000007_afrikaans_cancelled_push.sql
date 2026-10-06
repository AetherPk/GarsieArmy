-- "Gekanselleer" notification: the body needs a subject ("Die geleentheid op
-- Sa 12 Okt om 14:00 gaan nie meer voort nie."), not just a date.
-- The push migration already has the corrected text for new databases.
do $$
declare def text;
begin
  def := pg_get_functiondef('private.push_event_cancelled()'::regprocedure);
  execute replace(def, '''body'', private.af_when(old.date, old.start_time) || '' gaan nie meer voort nie.''',
                       '''body'', ''Die geleentheid op '' || private.af_when(old.date, old.start_time) || '' gaan nie meer voort nie.''');
end $$;
