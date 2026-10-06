-- Two sample events in September 2026 (in the past), so the calendar and
-- the "Verby" sections have something to show. Past events never send a
-- notification, so the trigger can stay on.
with d as (select id, name from public.departments)
insert into public.events (title, department_id, date, start_time, end_time, venue, description, ticket_url,
                           lat, lng, radius, address, audience_grades, audience_gender, audience_learners_only, created_by)
select v.title, d.id, v.date::date, v.s::time, v.e::time, v.venue, v.descr, null,
       -25.7972578, 28.305468, 250, 'Hoërskool Garsfontein, Jacqueline Drive, Constantia Park, Pretoria', '{}', 'all', v.learners, null
from (values
  ('Atletiek: interhuis',                   'Sport',    '2026-09-12', '08:00', '13:00', 'Atletiekbaan', 'Al vier huise hardloop vir punte.', false),
  ('Wiskunde-olimpiade: eerste rondte',     'Akademie', '2026-09-17', '14:00', '16:00', 'Mediasentrum', 'Die eerste rondte vir alle deelnemers.', true)
) as v(title, dept, date, s, e, venue, descr, learners)
join d on d.name = v.dept;
