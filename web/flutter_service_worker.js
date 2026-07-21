// Service worker "suicida" (kill-switch).
//
// Builds antiguos de esta app (antes de --pwa-strategy=none) registraban el
// service worker de Flutter, que sirve main.dart.js desde CacheStorage con
// estrategia cache-first: esos navegadores quedaban clavados en un build
// viejo PARA SIEMPRE, porque al intentar actualizar el SW el servidor les
// devolvía index.html (fallback SPA) y la actualización fallaba.
//
// Este archivo existe SOLO para esos clientes legados: el navegador que
// tenga registrado el SW viejo lo actualizará con este script, que al
// activarse borra todas las cachés, se desregistra a sí mismo y recarga las
// pestañas abiertas. Los navegadores sin SW registrado nunca lo piden
// (el bootstrap actual no registra ningún service worker).
//
// NO BORRAR: si desaparece, los clientes legados vuelven a quedar congelados.

self.addEventListener('install', () => {
  // Activarse de inmediato, sin esperar a que cierren las pestañas.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // 1. Borrar todas las cachés del origen (las del SW viejo de Flutter).
    const keys = await caches.keys();
    await Promise.all(keys.map((k) => caches.delete(k)));

    // 2. Desregistrarse: a partir de aquí todo va directo a la red.
    await self.registration.unregister();

    // 3. Recargar las pestañas controladas para que carguen el build nuevo.
    const clients = await self.clients.matchAll({ type: 'window' });
    await Promise.all(clients.map((c) => c.navigate(c.url).catch(() => {})));
  })());
});
