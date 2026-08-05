self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener('fetch', (event) => {
  // Le mode 'navigate' doit être géré pour l'installabilité PWA
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => {
        // En cas d'échec réseau, on laisse le navigateur gérer ou on pourrait servir une page offline
        return caches.match('/');
      })
    );
  }
});
