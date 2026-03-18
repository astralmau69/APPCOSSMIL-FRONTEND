# Instrucciones de Conexión a la API Real (COSSMIL)

Actualmente la aplicación está configurada para funcionar con **Datos Ficticios (Mocks)**. Esto se debe a que la API de autenticación (`http://10.150.10.13:9999`) solo es accesible desde la red local de la empresa.

## ¿Cuándo y Cómo Activar la API Real?

Cuando estés conectado a la red local de la empresa (Intranet) o tengas acceso por VPN a la IP `10.150.10.13`, debes reactivar el consumo real siguiendo este único y sencillo paso:

1. Abre el archivo: `lib/core/config/app_config.dart`
2. Cambia la variable `useMockData` de `true` a `false`:
   ```dart
   class AppConfig {
     static const bool useMockData = false; // <--- Cambiar a false
   }
   ```
3. Guarda el archivo y reinicia la aplicación. 

### ¿Qué sucederá al activarlo?
* El login comenzará a bloquear la interfaz hasta obtener respuesta del servidor real.
* El perfil del usuario, su CI, edad, matrícula y la tarjeta del "Titular" en la sección Familia se auto-completarán mágicamente con los datos devueltos por la base de datos de COSSMIL.
* Si el servidor devuelve un Error 401 (Credenciales incorrectas), la pantalla de login mostrará un banner de error real.

*(Nota interna: La configuración de Android para permitir tráfico local HTTP (`usesCleartextTraffic`) ya fue inyectada permanentemente por Antigravity en el `AndroidManifest.xml` y no necesitas volver a tocarla).*
