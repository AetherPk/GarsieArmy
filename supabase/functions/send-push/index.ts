// send-push: empties the push queue (see migrations/20260924000003_push.sql).
//
// The database decides WHO gets WHAT and puts it in the queue; this function
// only delivers. It is called by the database (pg_net) whenever something is
// queued, and again every minute while anything is waiting. Calling it more
// often is harmless, so it needs no secret: anyone calling it can only make
// queued messages go out sooner.
//
// VAPID keys come from Supabase Vault via push_config().
import { createClient } from "npm:@supabase/supabase-js@2.117.1";
import webpush from "npm:web-push@3.6.7";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const BATCH = 500;          // messages taken from the queue at a time
const PARALLEL = 50;        // sent at the same time
const TIME_LIMIT_MS = 100_000;

let configured = false;
async function configure() {
  if (configured) return;
  const { data, error } = await db.rpc("push_config").single();
  if (error || !data?.private_key) throw new Error("VAPID keys missing: " + (error?.message ?? "not in Vault"));
  webpush.setVapidDetails(data.subject, data.public_key, data.private_key);
  configured = true;
}

type Row = { id: number; endpoint: string; p256dh: string; auth: string; payload: unknown };

async function sendBatch(rows: Row[]) {
  const sent: number[] = [];
  const gone: string[] = [];
  for (let i = 0; i < rows.length; i += PARALLEL) {
    await Promise.all(rows.slice(i, i + PARALLEL).map(async (r) => {
      try {
        await webpush.sendNotification(
          { endpoint: r.endpoint, keys: { p256dh: r.p256dh, auth: r.auth } },
          JSON.stringify(r.payload),
          { TTL: 60 * 60 * 12, urgency: "high" },
        );
        sent.push(r.id);
      } catch (err) {
        const status = (err as { statusCode?: number }).statusCode;
        // 404/410: the phone unsubscribed or the app was removed.
        if (status === 404 || status === 410) gone.push(r.endpoint);
        // Other errors stay in the queue and are retried (max 3 times).
        else console.error("push failed", status, (err as Error).message);
      }
    }));
  }
  const { error } = await db.rpc("push_done", { p_sent: sent, p_gone: gone });
  if (error) console.error("push_done", error.message);
  return { sent: sent.length, gone: gone.length, failed: rows.length - sent.length - gone.length };
}

Deno.serve(async () => {
  const started = Date.now();
  const total = { sent: 0, gone: 0, failed: 0 };
  try {
    await configure();
    while (Date.now() - started < TIME_LIMIT_MS) {
      const { data, error } = await db.rpc("push_claim", { p_limit: BATCH });
      if (error) throw error;
      if (!data?.length) break;
      const r = await sendBatch(data as Row[]);
      total.sent += r.sent; total.gone += r.gone; total.failed += r.failed;
      if (data.length < BATCH) break;
    }
    return Response.json(total);
  } catch (err) {
    console.error(err);
    return Response.json({ ...total, error: (err as Error).message }, { status: 500 });
  }
});
