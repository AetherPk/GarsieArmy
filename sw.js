/* Garsie Army service worker.
   Keeps a copy of the app on the phone so it opens WITHOUT internet — that is
   what lets a learner scan an event QR code offline. The scan is stored on
   the phone and sent once it is back online (see "QR check-in" in the app).

   Bump CACHE whenever LIBS change, so phones fetch the new files. */
const CACHE = "garsie-v1";
const APP = "./garsie-army-prototype.html";
const LIBS = [
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css",
  "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js",
  "https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js",
  "https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.min.js"
];

self.addEventListener("install", ev => {
  ev.waitUntil(
    caches.open(CACHE)
      .then(cache => cache.addAll([APP, ...LIBS.map(url => new Request(url, { mode:"cors" }))]))
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
  if (LIBS.includes(req.url)){
    ev.respondWith(caches.match(req.url).then(hit => hit || fetch(req)));
  }
  // Everything else (map tiles, address search) goes to the network as normal.
});
