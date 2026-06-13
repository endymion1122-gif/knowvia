// Knowvia Service Worker — basic offline caching
const CACHE = "knowvia-v1";
const ASSETS = ["/", "/manifest.json"];

self.addEventListener("install", (e: any) => {
  e.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS))
  );
});

self.addEventListener("fetch", (e: any) => {
  // Cache-first for static assets, network-first for API
  if (e.request.url.includes("/api/")) {
    e.respondWith(
      fetch(e.request).catch(() => caches.match(e.request))
    );
  } else {
    e.respondWith(
      caches.match(e.request).then((cached) => cached || fetch(e.request))
    );
  }
});
