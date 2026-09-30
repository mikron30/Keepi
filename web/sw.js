const CACHE = 'keepi-app-shell-v3';
const SHELL = [
  '/app/',
  '/app/index.html',
  '/app/icons/Icon-192.png',
  '/app/icons/Icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (url.pathname === '/app/manifest.json') {
    event.respondWith(fetch(event.request, { cache: 'no-store' }));
    return;
  }

  if (event.request.mode === 'navigate' &&
      url.pathname.startsWith('/app/')) {
    event.respondWith((async () => {
      try {
        return await fetch(event.request, { cache: 'no-store' });
      } catch (_) {
        return (await caches.match('/app/index.html')) || Response.error();
      }
    })());
    return;
  }

  if (url.pathname.startsWith('/app/icons/')) {
    event.respondWith((async () => {
      const cached = await caches.match(event.request, { ignoreSearch: true });
      if (cached) return cached;
      return fetch(event.request);
    })());
  }
});
