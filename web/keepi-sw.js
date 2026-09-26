const KEEP_I_SW_VERSION = 'keepi-pwa-v1';

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// Chrome on Android expects an active service worker with a fetch handler
// for full WebAPK-style installation. Keepi deliberately stays network-first
// here so this worker does not bring back stale Flutter asset caching.
self.addEventListener('fetch', (event) => {
  const request = event.request;

  if (request.method !== 'GET') {
    return;
  }

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) {
    return;
  }

  event.respondWith(fetch(request));
});
