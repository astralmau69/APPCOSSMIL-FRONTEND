---
name: web-docker-lan-deploy
description: Cómo se sirve la versión web en Docker/LAN y por qué no debe depender de CDNs
metadata: 
  node_type: memory
  type: project
  originSessionId: 4bec9b20-df1a-4628-aa8e-7f7e133eade6
---

La versión web de COSSMIL se sirve con `docker compose up -d` (nginx en `0.0.0.0:8080`, proxy `/api/` → `https://api.cossmil.mil.bo` para evitar CORS). Los dispositivos que acceden lo hacen por `http://<IP-LAN>:8080` y **muchos no tienen salida a internet** (red interna militar).

**Why:** En julio 2026 la app quedaba EN BLANCO desde otros dispositivos porque el build web descargaba CanvasKit de `www.gstatic.com`, Roboto de `fonts.gstatic.com` y el SDK JS de Firebase de gstatic — todo inaccesible sin internet. Además `http://IP` no es contexto seguro: no hay service worker, ni API Notification (FCM web imposible), ni `crypto.subtle`.

**How to apply:**
- El build web del Dockerfile debe llevar SIEMPRE `--no-web-resources-cdn` (CanvasKit local).
- nginx.conf debe mandar `Cache-Control: no-cache` en TODO el estático (location /), no solo index.html: Flutter web no versiona main.dart.js/flutter_bootstrap.js/assets y la caché heurística del navegador seguía mostrando builds viejos ("no veo los cambios en docker", jul 2026). Con ETag las recargas son 304. Dispositivos que ya cachearon un build viejo necesitan UNA recarga forzada (Ctrl+Shift+R / borrar datos del sitio) la primera vez.
- Roboto va empaquetado en `assets/fonts/` + `pubspec.yaml` (familia `Roboto`); no quitar.
- `main.dart` inicializa Firebase con `.timeout()` y omite `PushNotificationService` en web cuando el origen no es https/localhost; mantener ese guard si se toca el arranque.
- **NUNCA llamar `flutter_secure_storage` en código alcanzable en web**: en `http://IP` su write con `crypto.subtle` no lanza excepción capturable — la promesa JS muere fuera de la zona Dart y el `await` cuelga para siempre (así se colgaba el login con spinner infinito, jul 2026). El try/catch NO protege. Patrón correcto: helpers `kIsWeb` → `webLsSet/webLsGet` (localStorage, datos no sensibles) o `webSecureSet/webSecureGet` (memoria+sessionStorage, tokens/credenciales) — ya aplicado en `SecurityService`, `SessionRestoreService`, `TokenStorage`. Pendientes conocidos con el mismo riesgo (rutas de reserva/ajustes): `notification_scheduler.dart`, `notification_preferences.dart`, `accounts_store.dart` (solo escrituras; las lecturas de claves inexistentes son seguras).
- Para probar "como otro dispositivo": Chrome headless (`--enable-unsafe-swiftshader` para que renderice) + CDP; `Network.setBlockedURLs` sobre `*gstatic.com*` simula LAN sin internet; `Fetch.enable` + `fulfillRequest` permite simular login exitoso sin credenciales reales; el árbol de semántica (`flt-semantics-placeholder`) da inputs DOM reales para automatizar formularios.
