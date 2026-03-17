# Cossmil App — Arquitectura Frontend Flutter

## Descripción General
App frontend pura en Flutter (Cupertino/iOS style), lista para consumir servicios REST del servidor.
No maneja lógica de negocio en el frontend: todo viene del backend.

---

## Stack y Tecnologías

| Herramienta | Descripción |
|---|---|
| Flutter (Cupertino) | UI estilo iOS — `CupertinoApp`, `CupertinoPageScaffold`, `CupertinoNavigationBar` |
| `http` | Cliente HTTP para llamadas REST |
| `flutter_secure_storage` | Almacenamiento seguro del token en el dispositivo |
| OAuth2 Password Grant | Flujo de autenticación con el servidor |

---

## Estructura de Carpetas

```
lib/
├── main.dart                          # Entry point — runApp
├── app.dart                           # CupertinoApp, rutas, tema
│
├── core/                              # Código compartido por toda la app
│   ├── constants/
│   │   └── api_constants.dart         # URLs base, endpoints, credenciales de app
│   ├── models/
│   │   └── auth_token_model.dart      # Modelo de respuesta del token
│   ├── services/
│   │   └── auth_service.dart          # Llamada HTTP al endpoint de autenticación
│   └── storage/
│       └── token_storage.dart         # Guardar/leer/borrar token seguro
│
└── features/                          # Funcionalidades separadas por módulo
    ├── auth/
    │   └── screens/
    │       └── login_screen.dart      # Pantalla de login (Cupertino)
    └── home/
        └── screens/
            └── home_screen.dart       # Pantalla principal post-login
```

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

### Body (form-urlencoded)
```
grant_type=password
username=<ingresado por el usuario>
password=<ingresado por el usuario>
```

### Respuesta esperada (200 OK)
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "scope": "...",
  "jti": "..."
}
```

### Credenciales de la App (NO del usuario)
- **username app:** `frontendapp`
- **password app:** `12345`
- Estas van en el header `Authorization: Basic` — son las credenciales del cliente OAuth2.
- El usuario ingresa sus propias credenciales en el formulario.

---

## Navegación y Rutas

| Ruta | Pantalla | Descripción |
|---|---|---|
| `/` o inicial | `LoginScreen` | Siempre arranca aquí si no hay token |
| `/home` | `HomeScreen` | Pantalla principal tras login exitoso |

> Pendiente: agregar más módulos debajo de `features/` según los servicios disponibles.

---

## Convenciones de Código

- **Un archivo = una responsabilidad** (SOLID - Single Responsibility)
- Archivos de servicio: solo lógica HTTP, sin UI
- Archivos de pantalla: solo UI, delegan lógica al servicio
- Modelos: solo estructura de datos + `fromJson`/`toJson`
- Constantes centralizadas en `api_constants.dart` — nunca hardcodear URLs en pantallas

---

## Próximos Módulos a Agregar

Agregar cada funcionalidad como un nuevo módulo en `features/`:

```
features/
├── auth/           ✅ Login
├── home/           ✅ Pantalla principal
├── perfil/         ⬜ Perfil del asegurado
├── polizas/        ⬜ Listado de pólizas
├── siniestros/     ⬜ Reporte de siniestros
└── contacto/       ⬜ Contacto / soporte
```

Cada nuevo servicio del servidor se agrega en `core/services/` con su propio archivo.

---

## Dependencias (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.2.0                    # Llamadas HTTP REST
  flutter_secure_storage: ^9.0.0  # Token seguro en dispositivo
```

---

## Notas de Seguridad

- El `access_token` se guarda con `flutter_secure_storage` (Keychain en iOS, Keystore en Android).
- Las credenciales de la app (`frontendapp/12345`) van hardcodeadas en `api_constants.dart`
  y se encodean en Base64 solo en tiempo de ejecución — NO se guardan en texto plano en disco.
- En producción: mover credenciales de app a variables de entorno o backend proxy.
