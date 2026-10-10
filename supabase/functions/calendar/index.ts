// calendar: a person's booked events ("Bespreek") as an iCalendar feed.
//
// Apple, Google and Outlook subscribe to
//   webcal://<project>.supabase.co/functions/v1/calendar?t=<token>
// and refresh it by themselves, so moves, renames and cancellations show up
// in the phone's calendar. The token comes from calendar_feed_on() in the app
// (Instellings ▸ Kalender). An unknown or switched-off token gives an empty
// calendar, so the events disappear at the next refresh.
//
// No sign-in here: calendar apps can't sign in. The token is the secret.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP = "https://aetherpk.github.io/GarsieArmy/garsie-army-prototype.html";

type Ev = { id: number; title: string; starts: string; ends: string; venue: string; address: string;
            description: string; department: string; updated_at: string };

const esc = (s: unknown) => String(s ?? "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
const utc = (iso: string) => new Date(iso).toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");

// Lines longer than 75 bytes are folded (RFC 5545), without splitting a character.
function fold(line: string): string {
  const enc = new TextEncoder();
  if (enc.encode(line).length <= 75) return line;
  const parts: string[] = [];
  let cur = "", len = 0, limit = 75;
  for (const ch of line) {
    const n = enc.encode(ch).length;
    if (len + n > limit) { parts.push(cur); cur = ""; len = 0; limit = 74; }
    cur += ch; len += n;
  }
  parts.push(cur);
  return parts.join("\r\n ");
}

function ics(events: Ev[]): string {
  const now = utc(new Date().toISOString());
  const lines = [
    "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Garsie Army//Hoerskool Garsfontein//AF", "CALSCALE:GREGORIAN", "METHOD:PUBLISH",
    "X-WR-CALNAME:Garsie Army", "X-WR-CALDESC:Geleenthede wat jy in Garsie Army bespreek het", "X-WR-TIMEZONE:Africa/Johannesburg",
    "REFRESH-INTERVAL;VALUE=DURATION:PT1H", "X-PUBLISHED-TTL:PT1H",
  ];
  for (const e of events) {
    const where = [e.venue, e.address].filter(Boolean).join(", ");
    const link = `${APP}#geleentheid=${e.id}`;
    const about = [e.department, e.description, `Oop in Garsie Army: ${link}`].filter(Boolean).join("\n\n");
    lines.push("BEGIN:VEVENT", `UID:event-${e.id}@garsiearmy`, `DTSTAMP:${now}`, `LAST-MODIFIED:${utc(e.updated_at)}`,
      `DTSTART:${utc(e.starts)}`, `DTEND:${utc(e.ends)}`, `SUMMARY:${esc(e.title)}`,
      ...(where ? [`LOCATION:${esc(where)}`] : []), `DESCRIPTION:${esc(about)}`, `URL:${link}`, "END:VEVENT");
  }
  lines.push("END:VCALENDAR");
  return lines.map(fold).join("\r\n") + "\r\n";
}

Deno.serve(async (req) => {
  const token = new URL(req.url).searchParams.get("t") ?? "";
  let events: Ev[] = [];
  if (/^[0-9a-f]{32,64}$/.test(token)) {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/calendar_feed_events`, {
      method: "POST",
      headers: { apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_token: token }),
    });
    if (res.ok) events = await res.json();
    else return new Response("Probeer later weer.", { status: 503 });
  }
  return new Response(ics(events), {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": 'inline; filename="garsie-army.ics"',
      "Cache-Control": "max-age=300",
    },
  });
});
