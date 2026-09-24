-- ============================================================================
-- Starting data: two departments, the first Hoof-admin, and the September
-- 2026 sample events (at the school; radius 250 m).
-- Safe to run once on an empty database.
-- ============================================================================

insert into public.departments (name, colour) values
  ('Sport',   '#c0262d'),
  ('Kultuur', '#5856d6');

-- The first Hoof-admin. Everyone else is added in the app (Bestuur).
insert into public.admins (email, role) values ('bernardmanne3@gmail.com', 'key');

with d as (select id, name from public.departments),
school as (select -25.7972578::float8 as lat, 28.305468::float8 as lng, 250 as radius,
                  'Hoërskool Garsfontein, Jacqueline Drive, Constantia Park, Pretoria'::text as address)
insert into public.events (title, department_id, date, start_time, end_time, venue, description, ticket_url,
                           lat, lng, radius, address, audience_grades, audience_gender, audience_learners_only, created_by)
select v.title, d.id, v.date::date, v.s::time, v.e::time, v.venue, v.descr, v.url,
       school.lat, school.lng, school.radius, school.address, v.grades::text[], v.gender, v.learners, null
from (values
  ('Landloop: interhuis',                 'Sport',   '2026-09-02','14:30','16:30','Atletiekbaan',   'Al vier huise hardloop vir punte. Kom moedig jou huis aan.',       null,                          '{}',          'all',    false),
  ('Krieket: Garsies teen Menlopark',     'Sport',   '2026-09-05','09:00','15:00','Hoofveld',       'Die eerste span se eerste wedstryd van die seisoen.',              null,                          '{}',          'all',    false),
  ('Redenaarskompetisie',                 'Kultuur', '2026-09-08','18:00','20:00','Kultuursentrum', 'Junior en senior redenaars in die finale ronde.',                 null,                          '{}',          'all',    false),
  ('Tennis: eerste span teen Waterkloof', 'Sport',   '2026-09-11','14:00','17:00','Tennisbane',     'Liga-wedstryd. Stoele is beperk — bring ''n kombers.',            null,                          '{}',          'all',    false),
  ('Swemgala',                            'Sport',   '2026-09-12','08:00','13:00','Swembad',        'Interhuis-swemgala. Kos en koeldrank te koop.',                   'https://www.quicket.co.za/',  '{}',          'all',    false),
  ('Kunsuitstalling',                     'Kultuur', '2026-09-15','17:30','20:00','Saal',           'Werk van die Graad 10–12-kunsleerders.',                         null,                          '{}',          'all',    false),
  ('Koor: lentekonsert',                  'Kultuur', '2026-09-17','19:00','21:00','Saal',           'Die koor sing die lente in.',                                     'https://www.quicket.co.za/',  '{}',          'all',    false),
  ('Atletiek: Noord-Gauteng-byeenkoms',   'Sport',   '2026-09-19','08:00','16:00','Atletiekbaan',   'Ons bied die streeksbyeenkoms aan. Parkering by die B-veld.',    null,                          '{}',          'all',    false),
  ('Debat: halfeindronde',                'Kultuur', '2026-09-22','15:00','17:00','Kultuursentrum', 'Ons senior span teen Menlopark.',                                 null,                          '{}',          'all',    false),
  ('Netbal: prysuitdeling',               'Sport',   '2026-09-23','18:00','20:00','Saal',           'Seisoen-afsluiting vir al die netbalspelers.',                    null,                          '{}',          'Meisie', true),
  ('Matriekafskeid',                      'Kultuur', '2026-09-25','18:30','23:00','Saal',           'Net vir die matrieks van 2026. Aantrek: formeel.',                'https://www.quicket.co.za/',  '{"Graad 12"}','all',    true),
  ('Krieket: o/15 teen Affies',           'Sport',   '2026-09-26','08:30','13:00','B-veld',         'Tuiswedstryd vir die o/15-span.',                                 null,                          '{}',          'all',    false),
  ('Toneelopvoering',                     'Kultuur', '2026-09-26','19:00','21:00','Kultuursentrum', 'Die dramaklub se eenbedrywe. Kaartjies is beperk.',               'https://www.quicket.co.za/',  '{}',          'all',    false),
  ('Oggendbyeenkoms: Erfenisweek',        'Kultuur', '2026-09-28','07:30','08:15','Saal',           'Kom in klere wat jou erfenis wys.',                               null,                          '{}',          'all',    false),
  ('Hokkie: somerliga',                   'Sport',   '2026-09-29','16:00','17:30','Kunsgrasveld',   'Eerste ronde van die somerliga.',                                 null,                          '{}',          'all',    false),
  ('Musiekaand',                          'Kultuur', '2026-09-30','18:30','20:30','Saal',           'Solo''s, ensembles en die orkes.',                                'https://www.quicket.co.za/',  '{}',          'all',    false)
) as v(title, dept, date, s, e, venue, descr, url, grades, gender, learners)
join d on d.name = v.dept
cross join school;
