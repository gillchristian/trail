// Trail service worker.
//
// Strategy:
//   - install: pre-cache the app shell (just '/' — Vite-built JS/CSS get
//     hashed names per build, so we let them fill the cache lazily on
//     first fetch).
//   - activate: drop any old caches whose name doesn't match the
//     current version. Forces a clean upgrade when we bump CACHE.
//   - fetch (GET only):
//       same-origin → stale-while-revalidate: serve cache hit, kick off
//         a background refresh that updates the cache for next time.
//       cross-origin → pass through to network (no caching). When the
//         map view ships (TASK-013) we'll add a tile-specific path.
//
// IMPORTANT: SW is only registered in production builds. Dev runs
// against Vite's HMR client which we deliberately don't cache.

const CACHE = 'trail-v1';

const APP_SHELL = [
  '/',
  '/index.html',
  '/manifest.webmanifest',
  '/icon.svg',
  '/icon-192.svg',
  '/icon-512.svg',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(APP_SHELL))
      .catch(() => {
        // Don't break installation if one shell URL is unreachable —
        // the lazy fetch handler will fill the cache anyway.
      })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;
  if (!sameOrigin) return;

  // Skip Vite dev-time URLs if for some reason we registered in dev.
  if (url.pathname.startsWith('/@vite') || url.pathname.startsWith('/@id') || url.pathname.startsWith('/@fs')) {
    return;
  }

  event.respondWith(
    caches.match(req).then((cached) => {
      const networkFetch = fetch(req)
        .then((resp) => {
          if (resp && resp.ok && resp.type === 'basic') {
            const clone = resp.clone();
            caches.open(CACHE).then((cache) => cache.put(req, clone));
          }
          return resp;
        })
        .catch(() => cached);

      return cached || networkFetch;
    })
  );
});
