# ── Etapa 1: build del web app con el SDK de Flutter ─────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Cachear pub get por separado del resto del código
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# API_BASE_URL vacía -> el app llama rutas relativas (/api/...) que nginx
# proxea hacia el backend real (ver nginx.conf). Así se evita el bloqueo
# CORS del navegador sin tocar el backend.
#
# --no-web-resources-cdn: sirve CanvasKit desde este mismo nginx en vez de
# www.gstatic.com. Sin esto, un dispositivo que llega por LAN pero no tiene
# internet no puede descargar el motor gráfico y la app queda EN BLANCO.
# --pwa-strategy=none: NO generar service worker. En esta app el SW solo aporta
# en contexto seguro (https/localhost); los dispositivos LAN llegan por http://IP
# (no seguro) y nunca lo usan. En cambio, en localhost el SW cacheaba main.dart.js
# y hacía que cada reconstrucción NO se reflejara (había que desregistrar el SW).
# Sin SW, la propagación de cada build depende solo de la revalidación HTTP
# (ETag/Last-Modified) que ya maneja nginx.
RUN flutter build web --release --no-web-resources-cdn --pwa-strategy=none --dart-define=API_BASE_URL=

# Cache-busting por build: Flutter web NO versiona sus archivos (main.dart.js
# y flutter_bootstrap.js conservan siempre el mismo nombre), así que un
# navegador con caché vieja puede quedarse mostrando un build anterior.
# Firmamos las referencias con ?v=<hash del build>: como index.html siempre
# se revalida (no-cache en nginx), cada build nuevo cambia las URLs y TODOS
# los clientes descargan el JS nuevo con una recarga normal, sin Ctrl+Shift+R.
RUN BUILD_HASH=$(md5sum build/web/main.dart.js | cut -c1-8) && \
    sed -i "s|flutter_bootstrap\.js|flutter_bootstrap.js?v=$BUILD_HASH|g" build/web/index.html && \
    sed -i "s|main\.dart\.js|main.dart.js?v=$BUILD_HASH|g" build/web/flutter_bootstrap.js && \
    echo "Cache-busting aplicado: v=$BUILD_HASH"

# ── Etapa 2: servir el build con nginx + proxy /api ──────────────────────────
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
