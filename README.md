# COSSMIL - Citas Médicas Militares

Aplicación móvil Flutter para la gestión de citas médicas dentro del sistema de la Corporación del Seguro Social Militar (COSSMIL). Proporciona una interfaz intuitiva para que los afiliados militares puedan reservar, gestionar y consultar sus citas médicas de forma segura y eficiente.

## Características

- Autenticación segura con OAuth2 y almacenamiento de tokens encriptado
- Reserva de citas médicas con selección de hospital, especialidad y médico
- Calendario de disponibilidad de médicos en tiempo real
- Gestión de grupo familiar (titular y beneficiarios)
- Consulta de citas médicas reservadas con confirmación mediante PDF
- Notificaciones programadas para recordatorios de citas (8 horas, 2 horas, 30 minutos antes)
- Autenticación biométrica local y sistema de PIN de seguridad
- Integración de contacto directo por WhatsApp
- Sistema de tutoriales guiados interactivos
- Pantalla de carga con precarga de datos críticos y no-críticos
- Diseño responsivo para múltiples tamaños de dispositivo
- Protección de pantalla para datos sensibles de salud
- Modo oscuro y claro

## Requisitos del Sistema

- Dart SDK: ^3.8.1
- Flutter: ^3.24.0
- Android: minSdk 21, targetSdk 34
- iOS: minVersion 12.0
- Java: JDK 21 (para builds en Android)
- Gradle: 8.x

## Dependencias Principales

- http: Cliente REST
- flutter_secure_storage: Almacenamiento encriptado de tokens y sesión
- local_auth: Autenticación biométrica
- crypto: Hashing de PIN (SHA-256)
- audioplayers: Reproducción de audio (splash, tutoriales)
- pdf / printing: Generación y vista previa de PDFs
- intl: Formateo de fechas y locales
- flutter_local_notifications / timezone: Recordatorios programados
- animate_do: Animaciones declarativas
- geolocator: Geolocalización para región más cercana
- url_launcher: Enlaces externos
- path_provider / open_file: Gestión de archivos

## Instalación y Configuración

### 1. Clonar el Repositorio

```bash
git clone https://gitea.cossmil.mil.bo/japaricioq/AppMovil.git
cd AppMovil
```

### 2. Instalar Dependencias

```bash
flutter pub get
```

### 3. Configuración de Secrets (Android)

En `android/key.properties`, proporcione las credenciales de firma:

```properties
storeFile=path/to/keystore.jks
storePassword=your_store_password
keyAlias=your_key_alias
keyPassword=your_key_password
```

Si el archivo no existe, el build de debug usará firmas por defecto.

### 4. Variables de Entorno

La configuración se encuentra en `lib/core/config/app_config.dart`. En producción, `useMockData` debe ser `false`.

## Ejecución

### Modo Debug

```bash
flutter run
```

### Con Emulador Específico

```bash
flutter run -d emulator-5554
```

### Build Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ipa --release
```

## Estructura del Proyecto

```
lib/
├── core/
│   ├── config/           Configuración global (endpoints, feature flags)
│   ├── constants/        Constantes (colores, valores, URLs)
│   ├── extensions/       Extensiones de Dart/Flutter
│   ├── models/           Modelos de datos compartidos
│   ├── services/         Servicios (HTTP, notificaciones, almacenamiento)
│   ├── session/          Gestión de sesión de usuario
│   ├── data/             Caché de sesión e inicialización de datos
│   ├── security/         Capa de seguridad (PIN, biometría, protección de pantalla)
│   ├── routing/          Enrutamiento global
│   ├── theme/            Temas (colores, tipografía, tokens de diseño)
│   ├── utils/            Utilidades (logging, sanitización)
│   ├── widgets/          Widgets reutilizables
│   ├── animations/       Animaciones y diálogos
│   └── mock/             Datos mock (solo desarrollo)
├── features/
│   ├── auth/             Flujo de autenticación
│   ├── splash/           Pantalla de inicio
│   ├── home/             Página principal
│   ├── booking/          Flujo de reserva de citas
│   ├── reservas/         Consulta de citas reservadas
│   ├── familia/          Gestión del grupo familiar
│   ├── perfil/           Perfil de usuario
│   ├── loading/          Pantalla de carga de datos
│   └── calendario/       Consulta de calendario de médicos
├── shell/
│   ├── tab_shell.dart    Navegación con pestañas y gestión de estado
│   └── widgets/          Widgets de navegación
├── main.dart             Punto de entrada
└── app.dart              Configuración de la aplicación

```

## Arquitectura

La aplicación sigue un patrón modular basado en features con gestión manual de estado mediante `setState` y objetos compartidos. 

### Componentes Clave

- **ApiClient**: Cliente HTTP centralizado con inyección automática de Bearer token y manejo de renovación de sesión
- **AuthService**: Servicio de autenticación OAuth2
- **SecurityService**: Gestión de PIN, biometría y timeouts de seguridad
- **NotificationService**: Servión de notificaciones y recordatorios programados
- **BookingState**: Objeto PODO compartido para el flujo multi-paso de reserva
- **UserSession / AppSessionCache**: Singletons en memoria con datos precargados de usuario

### Flujo de Autenticación

```
StartupRouter (verificación de sesión)
    ↓
SplashScreen (carga de datos)
    ↓
Login → LoadingDataScreen → TabShell (autenticado)
    ↓ (si es primer acceso o cambio de PIN)
SecuritySetup → PinSetup → Autenticación local
```

## Seguridad y Privacidad

- **Almacenamiento de Tokens**: Keychain (iOS) / Keystore (Android) mediante flutter_secure_storage
- **Sesión Persistente**: UserModel encriptado en almacenamiento seguro para reanudación sin relogin
- **PIN Local**: SHA-256 hasheado, nunca plaintext
- **Biometría**: Soporta huella dactilar y reconocimiento facial si está disponible
- **Protección de Pantalla**: FLAG_SECURE en Android, screenshot bloqueado en iOS
- **Sanitización de Logs**: Enmascaramiento automático de tokens, contraseñas e IDs de documento en salida debug
- **Sandbox de Documentos**: PDFs generados guardados en directorio privado de la aplicación, limpiado en logout

## Cambios Recientes

### Versión Actual

- Integración de WhatsApp directo en pantalla de contactos con número de soporte COSSMIL
- Sistema de tutoriales guiados mejorado con instructora animada
- Sincronización de audio en confirmación de citas (eliminación de solapamiento de voz)
- Feature gating para "Procedimientos COSSMIL" con badge "Próximamente" en pantalla de inicio
- Gestión independiente de soporte técnico (COSSMIL vs DNTIC)

## Desarrollo

### Análisis de Código

```bash
flutter analyze
```

### Ejecutar Tests

```bash
flutter test
flutter test test/widget_test.dart
```

### Formateo

```bash
dart format lib/
```

## API Backend

La aplicación consume una API REST en `https://api.cossmil.mil.bo`. Todos los endpoints requieren autenticación Bearer token.

### Formato de Respuesta

```json
{
  "ok": true,
  "status": 200,
  "message": "Success",
  "data": []
}
```

## Configuración del Entorno de Desarrollo

### Android

- SDK: `$ANDROID_SDK_ROOT` o `~/Android/Sdk`
- NDK: 27.0.12077973
- Gradle: 8.x (usa Kotlin DSL)
- Target: Java 11 con core library desugaring

### Compilar en Linux

Para sistemas Linux con recursos limitados:

```bash
# Limitar workers de Gradle
export GRADLE_OPTS="-Xmx3g"
./gradlew -q --max-workers=2 assembleDebug
```

## Manejo de Errores y Debugging

Todos los logs están protegidos por `kDebugMode`. En producción, no hay overhead de logging.

```bash
# Ver logs de la aplicación
flutter logs

# Debug detallado
flutter run -v
```

## Licencia

Propietario de COSSMIL - Corporación del Seguro Social Militar.

## Contacto y Soporte

Para consultas técnicas o reportar bugs, contactar a través de:
- WhatsApp: +591 71292794
- Correo electrónico: soporte@cossmil.mil.bo

## Contribuyentes

- Equipo de Desarrollo COSSMIL

---

Última actualización: 2026-08-03
