-- ============================================================================
-- Department colours (navy theme), Akademie as a department, and sample
-- events for October–December 2026. September's past events are removed.
-- The new-event notification is switched off while inserting, so phones
-- don't get two dozen "Nuwe geleentheid" messages for sample data.
-- ============================================================================

update public.departments set colour = '#3fae7a' where name = 'Sport';     -- veldgroen
update public.departments set colour = '#9b7fd4' where name = 'Kultuur';   -- ametis
insert into public.departments (name, colour) values ('Akademie', '#c9a23f')  -- goud
  on conflict do nothing;

delete from public.events where date < current_date;

alter table public.events disable trigger push_event_created;

with d as (select id, name from public.departments),
school as (select -25.7972578::float8 as lat, 28.305468::float8 as lng, 250 as radius,
                  'Hoërskool Garsfontein, Jacqueline Drive, Constantia Park, Pretoria'::text as address)
insert into public.events (title, department_id, date, start_time, end_time, venue, description, ticket_url,
                           lat, lng, radius, address, audience_grades, audience_gender, audience_learners_only, created_by)
select v.title, d.id, v.date::date, v.s::time, v.e::time, v.venue, v.descr, v.url,
       school.lat, school.lng, school.radius, school.address, v.grades::text[], v.gender, v.learners, null
from (values
  ('Toneel: eenbedrywe-aand',            'Kultuur',  '2026-10-09','19:00','21:00','Kultuursentrum', 'Die dramaklub se eenbedrywe. Plek is beperk.',            'https://www.quicket.co.za/', '{}', 'all', false),
  ('Krieket: Garsies teen Waterkloof',   'Sport',    '2026-10-10','09:00','16:00','Hoofveld',       'Die eerste span se tuiswedstryd.',                        null, '{}', 'all', false),
  ('Tennis: interhuis',                  'Sport',    '2026-10-14','14:00','17:00','Tennisbane',     'Al vier huise speel om die beker.',                       null, '{}', 'all', false),
  ('Wiskunde-olimpiade: tweede rondte',  'Akademie', '2026-10-15','14:00','16:00','Mediasentrum',   'Vir leerders wat deur die eerste rondte gekom het.',      null, '{}', 'all', true),
  ('Koor: lentekonsert',                 'Kultuur',  '2026-10-16','19:00','21:00','Saal',           'Die koor sing die lente in.',                             'https://www.quicket.co.za/', '{}', 'all', false),
  ('Swem: Noord-Gauteng-gala',           'Sport',    '2026-10-17','08:00','13:00','Swembad',        'Ons bied die streeksgala aan. Kos en koeldrank te koop.', 'https://www.quicket.co.za/', '{}', 'all', false),
  ('Hokkie: somerliga',                  'Sport',    '2026-10-21','16:00','17:30','Kunsgrasveld',   'Eerste ronde van die somerliga.',                         null, '{}', 'all', false),
  ('Graad 9: vakkeuse-aand',             'Akademie', '2026-10-22','18:00','19:30','Saal',           'Inligting oor die vakke vir Graad 10. Bring jou ouers saam.', null, '{"Graad 9"}', 'all', true),
  ('Kunsuitstalling',                    'Kultuur',  '2026-10-23','17:30','20:00','Saal',           'Werk van die Graad 10–12-kunsleerders.',                  null, '{}', 'all', false),
  ('Atletiek: seisoensopening',          'Sport',    '2026-10-24','08:00','13:00','Atletiekbaan',   'Die eerste byeenkoms van die seisoen.',                   null, '{}', 'all', false),
  ('Redenaars: finale',                  'Kultuur',  '2026-10-28','18:00','20:00','Kultuursentrum', 'Junior en senior redenaars in die finale ronde.',          null, '{}', 'all', false),
  ('Studiewenke voor die eksamen',       'Akademie', '2026-10-29','14:30','15:30','Mediasentrum',   'Hoe om slim vir die eindeksamen te leer.',                null, '{}', 'all', true),
  ('Krieket: o/15 teen Menlopark',       'Sport',    '2026-10-31','08:30','13:00','B-veld',         'Tuiswedstryd vir die o/15-span.',                         null, '{}', 'all', false),
  ('Eindeksamen begin',                  'Akademie', '2026-11-04','08:00','11:00','Saal',           'Die eerste vraestel. Wees betyds.',                       null, '{"Graad 8","Graad 9","Graad 10","Graad 11"}', 'all', true),
  ('Waterpolo: Garsies teen Affies',     'Sport',    '2026-11-06','15:30','17:00','Swembad',        'Eerste span teen Affies.',                                null, '{}', 'all', false),
  ('Robotika-uitstalling',               'Akademie', '2026-11-11','14:00','16:00','Tegnologiesentrum', 'Die robotikaklub wys sy projekte.',                   null, '{}', 'all', false),
  ('Orkes en ensembles',                 'Kultuur',  '2026-11-13','18:30','20:30','Saal',           'Die orkes en die ensembles se jaareindkonsert.',          'https://www.quicket.co.za/', '{}', 'all', false),
  ('Netbal: prysuitdeling',              'Sport',    '2026-11-20','18:00','20:00','Saal',           'Seisoenafsluiting vir al die netbalspelers.',             null, '{}', 'Meisie', true),
  ('Akademiese prysuitdeling',           'Akademie', '2026-11-25','18:00','20:30','Saal',           'Ons vereer die jaar se top-presteerders.',                null, '{}', 'all', false),
  ('Sportprysuitdeling',                 'Sport',    '2026-11-27','18:00','20:30','Saal',           'Die sportsterre van 2026.',                               null, '{}', 'all', false),
  ('Kersfees-sangdiens',                 'Kultuur',  '2026-12-02','18:30','20:00','Saal',           'Kerssange met die koor en die orkes.',                    null, '{}', 'all', false),
  ('Laaste skooldag',                    'Akademie', '2026-12-04','08:00','11:00','Saal',           'Rapporte en die laaste saalbyeenkoms van 2026.',          null, '{"Graad 8","Graad 9","Graad 10","Graad 11"}', 'all', true)
) as v(title, dept, date, s, e, venue, descr, url, grades, gender, learners)
join d on d.name = v.dept
cross join school;

alter table public.events enable trigger push_event_created;
