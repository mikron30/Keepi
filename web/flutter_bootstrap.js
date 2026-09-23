{{flutter_js}}
{{flutter_build_config}}

async function startKeepi() {
  if ('serviceWorker' in navigator) {
    try {
      const registrations = await navigator.serviceWorker.getRegistrations();
      await Promise.all(registrations.map((registration) => registration.unregister()));

      if ('caches' in window) {
        const cacheNames = await caches.keys();
        await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
      }
    } catch (error) {
      console.warn('Keepi cache cleanup warning:', error);
    }
  }

  await _flutter.loader.load();
}

startKeepi();
