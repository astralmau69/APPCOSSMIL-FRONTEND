# Cossmil App — Arquitectura Frontend Flutter

## Descripción General
App frontend pura en Flutter (Cupertino/iOS style), lista para consumir servicios REST del servidor.
No maneja lógica de negocio en el frontend: todo viene del backend.

---

## Stack y Tecnologías

| Herramienta | Descripción |
|---|---|
| Flutter (Cupertino) | UI estilo iOS — `CupertinoTabScaffold`, `CupertinoPageScaffold`, `CupertinoNavigationBar` |
| `http` | Cliente HTTP para llamadas REST |
| `flutter_secure_storage` | Almacenamiento seguro del token en el dispositivo |
| OAuth2 Password Grant | Flujo de autenticación con el servidor |
| `pdf` + `printing` | Generación de ticket PDF de reserva |
| `audioplayers` | Audio en splash screen |
| `intl` | Formateo de fechas/horas |

---

## Estructura de Carpetas

```
lib/
├── main.dart                           # Entry point — runApp
├── app.dart                            # MaterialApp, rutas, tema, lifecycle
│
├── core/                               # Código compartido por toda la app
│   ├── animations/
│   │   ├── animated_press_button.dart  # Botón con efecto de press
│   │   ├── animated_status_badge.dart  # Badge animado de estado
│   │   ├── app_page_route.dart         # CupertinoPageRoute personalizado
│   │   ├── fade_slide_in.dart          # Animación entrada con fade + slide
│   │   └── optimized_animations.dart   # Widgets de animación optimizados
│   ├── config/
│   │   └── app_config.dart             # Toggle useMockData para dev offline
│   ├── constants/
│   │   ├── api_constants.dart          # URLs base, endpoints, credenciales OAuth2
│   │   └── app_colors.dart             # Paleta de colores centralizada
│   ├── extensions/
│   │   └── responsive_extensions.dart  # Helpers responsive (isSmallPhone, isTablet)
│   ├── mock/
│   │   ├── mock_appointments_data.dart # Datos mock de citas
│   │   ├── mock_news_data.dart         # Datos mock de noticias
│   │   ├── mock_regional_data.dart     # Datos mock de regionales
│   │   ├── mock_schedule_data.dart     # Datos mock de horarios
│   │   ├── mock_specialty_data.dart    # Datos mock de especialidades
│   │   └── mock_user_data.dart         # Datos mock de usuario
│   ├── models/
│   │   ├── appointment_model.dart      # Modelo de cita (fromJson/toJson)
│   │   ├── auth_token_model.dart       # Modelo de token OAuth2
│   │   ├── beneficiary_model.dart      # Modelo de beneficiario (fromJson/toJson)
│   │   ├── doctor_model.dart           # Modelo de médico (fromJson/toJson)
│   │   ├── hospital_model.dart         # Modelo de hospital (fromJson/toJson)
│   │   ├── news_item_model.dart        # Modelo de noticia
│   │   ├── regional_model.dart         # Modelo de regional (fromJson/toJson)
│   │   ├── specialty_model.dart        # Modelo de especialidad (fromJson/toJson)
│   │   ├── time_slot_model.dart        # Modelo de horario (fromJson/toJson)
│   │   └── user_model.dart             # Modelo de usuario (fromJson/toJson)
│   ├── services/
│   │   ├── api_client.dart             # Cliente HTTP con Bearer token auto
│   │   ├── auth_service.dart           # Login OAuth2 + carga de perfil
│   │   ├── booking_service.dart        # Servicio de reservas (mock/real)
│   │   ├── pdf_service.dart            # Generación de ticket PDF
│   │   └── programacion_service.dart   # Regionales, especialidades (API real)
│   ├── storage/
│   │   └── token_storage.dart          # Guardar/leer/borrar token seguro
│   ├── theme/
│   │   ├── app_constants.dart          # Design tokens: AppTypography, AppSpacing, AppShadows, AppDurations, AppCurves
│   │   ├── app_theme.dart              # ThemeData centralizado
│   │   └── app_theme_responsive.dart   # Extensiones responsive del tema
│   └── widgets/
│       ├── appointment_card.dart       # Tarjeta de cita reutilizable
│       ├── beneficiary_selector_modal.dart # Modal para seleccionar beneficiario
│       ├── breadcrumb_chips.dart        # Chips de breadcrumb de navegación
│       ├── cossmil_ios_alert.dart       # Alerta estilo iOS nativa
│       ├── image_banner.dart            # Banner de imagen reutilizable
│       ├── news_card.dart               # Tarjeta de noticia
│       ├── profile_qr_modal.dart        # Modal QR de perfil
│       ├── section_header.dart          # Cabecera de sección reutilizable
│       └── text_section.dart            # Bloque título + cuerpo reutilizable
│
├── features/                            # Funcionalidades separadas por módulo
│   ├── auth/
│   │   └── screens/
│   │       └── login_screen.dart        # Pantalla de login (OAuth2)
│   ├── booking/
│   │   └── screens/
│   │       ├── regional_screen.dart     # Selección de regional/hospital
│   │       ├── specialty_screen.dart    # Selección de especialidad
│   │       ├── schedule_screen.dart     # Selección de horario
│   │       └── summary_screen.dart      # Resumen y confirmación
│   ├── familia/
│   │   └── screens/
│   │       └── familia_screen.dart      # Listado de beneficiarios
│   ├── home/
│   │   └── screens/
│   │       ├── contactos_screen.dart    # Directorio de contactos
│   │       ├── home_screen.dart         # Pantalla principal (perfil + acciones + noticias)
│   │       └── noticias_screen.dart     # Listado completo de noticias
│   ├── perfil/
│   │   └── screens/
│   │       └── perfil_screen.dart       # Perfil del usuario
│   ├── reservas/
│   │   └── screens/
│   │       └── reservas_screen.dart     # Historial de reservas
│   └── splash/
│       └── screens/
│           └── splash_screen.dart       # Splash screen (entrada + overlay)
│
└── shell/
    └── tab_shell.dart                   # CupertinoTabScaffold + BookingState compartido
```

---

## Patrones Arquitectónicos

### Gestión de Estado
- **setState + BookingState compartido**: Estado mutable del flujo de reserva gestionado en `TabShellState`.
- No se usa Riverpod, BLoC ni Provider — decisión de proyecto para simplicidad.

### Diseño de Servicios
- **ApiClient**: Cliente HTTP centralizado con Bearer token automático. Retorna `sealed class ApiClientResponse` (Success/Error).
- **AuthService**: Login OAuth2 con `sealed class AuthResult`. Soporta mock data.
- **ProgramacionService**: Consume endpoints de programación. Pattern matching con `switch` (Dart 3).

### Sistema de Diseño (Design Tokens)
- `AppColors` — Paleta institucional (azul + verde médico + dorado).
- `AppTypography` — Sistema tipográfico completo (display → caption).
- `AppSpacing` — Escala de 4px para espaciado, radios, iconos, avatares.
- `AppShadows` — 6 niveles de elevación (hairline → veryElevated).
- `AppDurations` / `AppCurves` — Constantes de animación.

### Serialización de Modelos
- Todos los modelos tienen `fromJson` / `toJson` manual (sin build_runner).
- Claves duales: soportan naming backend en español + fallback en inglés.

---

## Navegación y Rutas

| Ruta | Pantalla | Descripción |
|---|---|---|
| Splash inicial | `SplashScreen` | Arranca aquí, luego navega a login o home |
| `/login` | `LoginScreen` | Login OAuth2 si no hay token |
| `/home` | `TabShell` | Tabs: Inicio, Reservas, Reservar, Familia, Perfil |

### Booking Flow (dentro del tab "Reservar"):
`RegionalScreen` → `SpecialtyScreen` → `ScheduleScreen` → `SummaryScreen`

---

## Autenticación — Flujo OAuth2 Password Grant

### Endpoint
```
POST http://10.150.10.13:9999/api/security/oauth/token
```

### Headers
```
Authorization: Basic ZnJvbnRlbmRhcHA6MTIzNDU=   ← base64("frontendapp:12345")
Content-Type: application/x-www-form-urlencoded
```

### Respuesta exitosa
El `access_token` se almacena con `flutter_secure_storage` (Keychain/Keystore).

---

## Convenciones de Código

- **Un archivo = una responsabilidad** (Single Responsibility)
- **Servicios**: solo lógica HTTP, sin UI. Aceptan `http.Client` opcional para tests.
- **Pantallas**: solo UI, delegan lógica al servicio.
- **Modelos**: estructura de datos + `fromJson`/`toJson` manual.
- **Constantes centralizadas**: nunca hardcodear URLs ni colores en pantallas.
- **Tipografía centralizada**: usar `AppTypography.*` en lugar de `TextStyle()` inline.
- **Idioma**: textos UI en español, código y documentación mixto.
- **Widgets reutilizables**: `SectionHeader`, `TextSection`, `ImageBanner`, `NewsCard`, etc.

---

## Notas de Seguridad

- El `access_token` se guarda con `flutter_secure_storage`.
- Las credenciales de la app (`frontendapp/12345`) se encodean en Base64 en runtime.
- En producción: mover credenciales de app a variables de entorno o backend proxy.
