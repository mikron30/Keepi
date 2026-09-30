const CACHE = 'keepi-app-runtime-v5';

self.addEventListener('install', (event) => {
  // Never let optional precaching prevent the worker from installing.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);

    // Best-effort warm-up only. A failed asset must not fail activation.
    await Promise.allSettled([
      fetch('/app/index.html', { cache: 'no-store' })
        .then((response) => response.ok ? cache.put('/app/index.html', response.clone()) : undefined),
      fetch('/app/icons/Icon-192.png', { cache: 'no-store' })
        .then((response) => response.ok ? cache.put('/app/icons/Icon-192.png', response.clone()) : undefined),
      fetch('/app/icons/Icon-512.png', { cache: 'no-store' })
        .then((response) => response.ok ? cache.put('/app/icons/Icon-512.png', response.clone()) : undefined)
    ]);

    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  if (url.pathname === '/app/manifest.json' ||
      url.pathname === '/app/sw.js') {
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
        const cached = await caches.match('/app/index.html');
        if (cached) return cached;

        return new Response(
          '<!doctype html><html><meta name="viewport" content="width=device-width"><body style="font-family:sans-serif;background:#0D1020;color:white;padding:24px"><h1>Keepi</h1><p>You are offline. Reconnect and try again.</p></body></html>',
          { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
        );
      }
    })());
    return;
  }

  if (url.pathname.startsWith('/app/icons/')) {
    event.respondWith((async () => {
      const cached = await caches.match(url.pathname);
      if (cached) return cached;

      const response = await fetch(event.request);
      if (response && response.ok) {
        const cache = await caches.open(CACHE);
        cache.put(url.pathname, response.clone());
      }
      return response;
    })());
  }
});
