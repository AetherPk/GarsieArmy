-- Check-in only counts inside the event's circle, for the "Meld aan" button
-- AND for QR scans. Before, a check-in from outside (or without a location)
-- was stored with a flag for an admin to review; now it is turned away.
-- The circle gets the phone's GPS accuracy as leeway (at most 100 m), since
-- a fix near the edge can wobble. Location works offline (GPS), so a scan
-- saved without internet still carries where it was made.
create or replace function public.checkin(
  p_event_id bigint, p_method text, p_token text, p_scanned_at timestamptz,
  p_lat double precision, p_lng double precision, p_accuracy double precision, p_device text)
returns jsonb language plpgsql volatile security definer set search_path = '' as
$$
declare
  uid uuid := auth.uid();
  e public.events%rowtype;
  flags text[] := '{}';
  dist integer;
  parts text[];
  scanned timestamptz := least(coalesce(p_scanned_at, now()), now());   -- no future times
  age bigint;
begin
  if uid is null then return jsonb_build_object('status','error','message','Teken eers in.'); end if;
  select * into e from public.events where id = p_event_id;
  if not found then return jsonb_build_object('status','error','message','Hierdie geleentheid bestaan nie meer nie.'); end if;
  if not (private.fits_audience(e.audience_grades, e.audience_gender, e.audience_learners_only, uid) or private.can_admin(e.department_id)) then
    return jsonb_build_object('status','error','message','Hierdie geleentheid is nie vir jou nie.');
  end if;
  if exists (select 1 from public.checkins c where c.event_id = e.id and c.user_id = uid) then
    return jsonb_build_object('status','ok','message','Jy is reeds aangemeld.');
  end if;
  if scanned < now() - interval '7 days' then
    return jsonb_build_object('status','error','message','Hierdie skandering is te oud om nog te tel.');
  end if;

  if p_method in ('qr-live','qr-print') then
    parts := string_to_array(coalesce(p_token, ''), '.');
    if array_length(parts, 1) <> 3 or parts[1] <> e.id::text
       or parts[3] is distinct from private.qr_sig(e.id, parts[2])
       or (p_method = 'qr-print') <> (parts[2] = 'p') then
      return jsonb_build_object('status','error','message','Hierdie QR-kode is ongeldig.');
    end if;
    if parts[2] <> 'p' then
      age := floor(extract(epoch from scanned) / 30)::bigint - parts[2]::bigint;
      if age > 2 or age < -1 then flags := array_append(flags, 'QR-kode was ouer as ''n minuut (moontlik aangestuur)'); end if;
    end if;
  elsif p_method <> 'gps' then
    return jsonb_build_object('status','error','message','Onbekende aanmeldmetode.');
  end if;

  -- Must be inside the circle.
  if p_lat is null or p_lng is null then
    return jsonb_build_object('status','error','message','Ons kon nie jou ligging kry nie. Skakel jou ligging aan en probeer weer — jy moet by die geleentheid wees om aan te meld.');
  end if;
  dist := round(2 * 6371000 * asin(sqrt(
            power(sin(radians(e.lat - p_lat) / 2), 2) +
            cos(radians(p_lat)) * cos(radians(e.lat)) * power(sin(radians(e.lng - p_lng) / 2), 2))));
  if dist > e.radius + least(coalesce(p_accuracy, 0), 100) then
    return jsonb_build_object('status','error','message','Jy is ' ||
      case when dist < 1000 then dist || ' m' else replace(round(dist / 1000.0, 1)::text, '.', ',') || ' km' end ||
      ' van die geleentheid af. Jy moet binne die area wees om aan te meld.');
  end if;

  insert into public.checkins (event_id, user_id, scanned_at, lat, lng, accuracy, distance_m, method, device_id, flags)
  values (e.id, uid, scanned, p_lat, p_lng, p_accuracy, dist, p_method, left(p_device, 64), flags)
  on conflict (event_id, user_id) do nothing;

  if array_length(flags, 1) > 0 then
    return jsonb_build_object('status','flagged','message','Ontvang. Die QR-kode was ouer as ''n minuut — ''n admin sal dit nagaan.');
  end if;
  return jsonb_build_object('status','ok','message','Jy is aangemeld by ' || e.title || '!');
end $$;
