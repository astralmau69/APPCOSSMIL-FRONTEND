# Instrucciones de Conexión a la API Real (COSSMIL)

La aplicación consume en producción la API **por HTTPS**: `https://api.cossmil.mil.bo` (configurada en `lib/core/constants/api_constants.dart`). La IP interna `http://10.150.10.13:9999` solo se usa para pruebas dentro de la red local de la empresa y permanece **comentada** en el código.

## ¿Cuándo y Cómo Activar Datos Reales (en lugar de Mocks)?

Si necesitas probar contra el servidor real (estando con acceso al dominio HTTPS o, internamente, por VPN a la IP `10.150.10.13`), reactiva el consumo real siguiendo este único y sencillo paso:

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

*(Nota de seguridad: la app **bloquea el tráfico HTTP en texto plano**. Android lo prohíbe vía `network_security_config.xml` (`cleartextTrafficPermitted="false"`) e iOS por ATS por defecto. Producción es solo HTTPS. Si necesitaras probar contra la IP interna por HTTP, tendrías que habilitar cleartext temporalmente — **no lo dejes activado en releases**.)*
