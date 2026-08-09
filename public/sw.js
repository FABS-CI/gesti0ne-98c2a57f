const CACHE_NAME = 'gesti-one-v2';
const ASSETS_TO_CACHE = [
  '/manifest.webmanifest',
  '/favicon.png',
  '/icon-192x192.png',
  '/icon-512x512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS_TO_CACHE))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.filter((cacheName) => cacheName !== CACHE_NAME)
          .map((cacheName) => caches.delete(cacheName))
      );
    }).then(() => clients.claim())
  );
});

// Ressources sûres à mettre en cache (immuables / statiques)
function isCacheableAsset(url) {
  return /\.(png|jpg|jpeg|svg|webp|gif|ico|woff2?|ttf)$/i.test(new URL(url).pathname)
    || new URL(url).pathname === '/manifest.webmanifest';
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET' || !req.url.startsWith('http')) return;
  if (req.url.includes('/api/') || req.url.includes('supabase.co')) return;

  // Images / polices : cache d'abord
  if (isCacheableAsset(req.url)) {
    event.respondWith(
      caches.match(req).then((cached) =>
        cached ||
        fetch(req).then((res) => {
          if (res.status === 200) {
            const clone = res.clone();
            caches.open(CACHE_NAME).then((c) => c.put(req, clone));
          }
          return res;
        }),
      ),
    );
    return;
  }

  // Code applicatif (JS/CSS) et navigations : réseau d'abord, cache en secours
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res.status === 200 && req.mode === 'navigate') {
          const clone = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put(req, clone));
        }
        return res;
      })
      .catch(() =>
        caches.match(req).then((cached) => {
          if (cached) return cached;
          if (req.mode === 'navigate') return caches.match('/');
          return Response.error();
        }),
      ),
  );
});
