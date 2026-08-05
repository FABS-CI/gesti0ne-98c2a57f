self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener('fetch', (event: FetchEvent) => {
  // Simple network-first strategy for dynamic resources
  // and stale-while-revalidate for static ones could be added here
  // For now, we focus on installability which requires a fetch handler
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request));
  }
});
