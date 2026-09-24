/* Garsie Army service worker.
   Keeps a copy of the app on the phone so it opens WITHOUT internet — that is
   what lets a learner scan an event QR code offline. The scan is stored on
   the phone and sent once it is back online (see "QR check-in" in the app).

   It also receives push notifications (see "Push" at the bottom).

   Bump CACHE whenever LIBS change, so phones fetch the new files. */
const CACHE = "garsie-v4";
const APP = "./garsie-army-prototype.html";
const FILES = ["./manifest.json", "./icons/icon-192.png", "./icons/badge-96.png"];
// The map library (~1 MB) is saved the first time a map is shown, not at
// install: keep in step with VECTOR_LIBS in the app.
const VECTOR_LIBS = [
  "https://cdn.jsdelivr.net/npm/maplibre-gl@5.24.0/dist/maplibre-gl.css",
  "https://cdn.jsdelivr.net/npm/maplibre-gl@5.24.0/dist/maplibre-gl.js",
  "https://cdn.jsdelivr.net/npm/@maplibre/maplibre-gl-leaflet@0.1.4/leaflet-maplibre-gl.js"
];
const LIBS = [
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css",
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js",
  "https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js",
  "https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.min.js",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.1/dist/umd/supabase.js"
];

self.addEventListener("install", ev => {
  ev.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll([APP, ...FILES, ...LIBS.map(url => new Request(url, { mode:"cors" }))]))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", ev => {
  ev.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// A fetch that gives up after `ms`, so a bad connection falls back to the
// cached app quickly instead of hanging.
function fetchWithTimeout(req, ms){
  return Promise.race([
    fetch(req),
    new Promise((_, reject) => setTimeout(() => reject(new Error("timeout")), ms))
  ]);
}

self.addEventListener("fetch", ev => {
  const req = ev.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // The app page: try the network first (so updates arrive), fall back to
  // the saved copy when offline. Opening a QR link like
  // ...garsie-army-prototype.html#aanmeld=... lands here too.
  if (req.mode === "navigate" && url.pathname.endsWith("/garsie-army-prototype.html")){
    ev.respondWith(
      fetchWithTimeout(req, 5000)
        .then(res => {
          if (res.ok){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(APP, copy)); }
          return res;
        })
        .catch(() => caches.match(APP))
    );
    return;
  }

  // Libraries have version numbers in their URLs, so the saved copy is always right.
  if (LIBS.includes(req.url) || FILES.some(f => new URL(f, self.registration.scope).href === req.url)){
    ev.respondWith(caches.match(req.url).then(hit => hit || fetch(req)));
  }
  if (VECTOR_LIBS.includes(req.url)){
    ev.respondWith(caches.match(req.url).then(hit => hit || fetch(req).then(res => {
      if (res.ok){ const copy = res.clone(); caches.open(CACHE).then(c => c.put(req.url, copy)); }
      return res;
    })));
    return;
  }
  // Everything else (map tiles, address search) goes to the network as normal.
});

/* ---- Push ------------------------------------------------------------------
   The server sends { title, body, url, tag }. A newer message with the same
   tag (same event) replaces the older one instead of piling up. */
self.addEventListener("push", ev => {
  let d = {};
  try { d = ev.data ? ev.data.json() : {}; } catch { d = { body: ev.data ? ev.data.text() : "" }; }
  ev.waitUntil(self.registration.showNotification(d.title || "Garsie Army", {
    body: d.body || "",
    tag: d.tag,
    renotify: !!d.tag,
    icon: "icons/icon-192.png",
    badge: "icons/badge-96.png",
    lang: "af",
    data: { url: new URL(d.url || APP, self.registration.scope).href }
  }));
});

// Tapping a notification: use the open app if there is one, else open it.
self.addEventListener("notificationclick", ev => {
  ev.notification.close();
  const url = (ev.notification.data && ev.notification.data.url) || new URL(APP, self.registration.scope).href;
  ev.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type:"window", includeUncontrolled:true });
    const app = wins.find(w => new URL(w.url).pathname.endsWith("/garsie-army-prototype.html"));
    if (app){
      await app.focus();
      app.postMessage({ type:"open", hash:new URL(url).hash });
      return;
    }
    await self.clients.openWindow(url);
  })());
});
