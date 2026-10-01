const CACHE = 'keepi-app-runtime-v6';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter((key) => key.startsWith('keepi-app-runtime-') && key !== CACHE)
        .map((key) => caches.delete(key))
    );

    const cache = await caches.open(CACHE);

    // Best-effort shell warm-up only. Icons and manifest must always stay fresh.
    await Promise.allSettled([
      fetch('/app/index.html', { cache: 'no-store' })
        .then((response) => response.ok ? cache.put('/app/index.html', response.clone()) : undefined)
    ]);

    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (
    url.pathname === '/app/manifest.json' ||
    url.pathname === '/app/sw.js' ||
    url.pathname.startsWith('/app/icons/')
  ) {
    event.respondWith(fetch(event.request, { cache: 'no-store' }));
    return;
  }

  if (event.request.mode === 'navigate' && url.pathname.startsWith('/app/')) {
    event.respondWith((async () => {
      try {
        const response = await fetch(event.request, { cache: 'no-store' });
        if (response && response.ok) {
          const cache = await caches.open(CACHE);
          cache.put('/app/index.html', response.clone());
        }
        return response;
      } catch (_) {
        const cache = await caches.open(CACHE);
        const cached = await cache.match('/app/index.html');
        if (cached) return cached;

        return new Response(
          '<!doctype html><html><meta name="viewport" content="width=device-width"><body style="font-family:sans-serif;background:#0D1020;color:white;padding:24px"><h1>Keepi</h1><p>You are offline. Reconnect and try again.</p></body></html>',
          { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        );
      }
    })());
  }
});
