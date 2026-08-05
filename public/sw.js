const CACHE_NAME = 'gesti-one-v1';
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/manifest.webmanifest',
  '/favicon.png',
  '/icon-192x192.png',
  '/icon-512x512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(ASSETS_TO_CACHE);
    })
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

self.addEventListener('fetch', (event) => {
  // Ignorer les requêtes non-GET et les schémas non supportés (chrome-extension, etc.)
  if (event.request.method !== 'GET' || !event.request.url.startsWith('http')) {
    return;
  }

  event.respondWith(
    caches.match(event.request).then((response) => {
      // Retourne le cache s'il existe, sinon fait la requête réseau
      return response || fetch(event.request).then((fetchResponse) => {
        // Ne pas mettre en cache les réponses d'API ou d'auth (Supabase)
        if (event.request.url.includes('/api/') || event.request.url.includes('supabase.co')) {
          return fetchResponse;
        }

        return caches.open(CACHE_NAME).then((cache) => {
          // On ne clone que les succès pour éviter de polluer le cache
          if (fetchResponse.status === 200) {
            cache.put(event.request, fetchResponse.clone());
          }
          return fetchResponse;
        });
      });
    }).catch(() => {
      // Fallback offline pour les navigations
      if (event.request.mode === 'navigate') {
        return caches.match('/');
      }
    })
  );
});
