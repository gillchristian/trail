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

const CACHE = 'trail-v2';
const TILE_CACHE = 'trail-tiles-v1';
const TILE_CACHE_MAX = 800; // ~25 MB at typical tile sizes

const APP_SHELL = [
  '/',
  '/index.html',
  '/manifest.webmanifest',
  '/icon.svg',
  '/icon-192.svg',
  '/icon-512.svg',
];

function isTileRequest(url) {
  // Any OpenStreetMap mirror's /Z/X/Y.png tile path.
  return /^https:\/\/[a-c]\.tile\.openstreetmap\.org\/\d+\/\d+\/\d+\.png$/.test(url);
}

async function trimTileCache() {
  const cache = await caches.open(TILE_CACHE);
  const keys = await cache.keys();
  if (keys.length <= TILE_CACHE_MAX) return;
  const overflow = keys.length - TILE_CACHE_MAX;
  // FIFO: keys() returns insertion order, so the oldest are at the front.
  await Promise.all(keys.slice(0, overflow).map((k) => cache.delete(k)));
}

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
  const keep = new Set([CACHE, TILE_CACHE]);
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => !keep.has(k)).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);

  // OSM tile: cache-first. Tiles are immutable per Z/X/Y, so once we have
  // them we never need to re-fetch — perfect for offline race-day use.
  if (isTileRequest(url.toString())) {
    event.respondWith(
      caches.open(TILE_CACHE).then(async (cache) => {
        const cached = await cache.match(req);
        if (cached) return cached;
        try {
          const resp = await fetch(req);
          if (resp && resp.ok) {
            cache.put(req, resp.clone());
            trimTileCache();
          }
          return resp;
        } catch (e) {
          // Offline + uncached tile: return a 504 so Leaflet shows its
          // blank-tile fallback instead of choking.
          return new Response('', { status: 504, statusText: 'Offline' });
        }
      })
    );
    return;
  }

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
