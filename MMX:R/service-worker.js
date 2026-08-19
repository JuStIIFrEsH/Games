const CACHE = "regenesis-local-launcher-v2";
const ASSETS = [
  "./icon-192.png",
  "./icon-512.png",
  "./index.html",
  "./index.js",
  "./index.wasm",
  "./launcher_shell.html",
  "./manifest.webmanifest"
];

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE)
      .then(async cache => {
        for (const asset of ASSETS) {
          await cache.add(asset);
        }
      })
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(names => Promise.all(
        names.filter(n => n.startsWith("regenesis-local-launcher-") && n !== CACHE)
             .map(n => caches.delete(n))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;

  if (event.request.mode === "navigate") {
    event.respondWith(
      caches.match("./index.html", { ignoreSearch: true })
        .then(hit => hit || fetch(event.request))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request, { ignoreSearch: true })
      .then(hit => hit || fetch(event.request))
  );
});
