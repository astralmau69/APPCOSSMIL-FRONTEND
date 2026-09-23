---
name: phi-hardening-seguridad
description: "Capas de seguridad para datos de salud (PHI/PII) — FLAG_SECURE, enmascarado de logs, sandbox de PDFs con limpieza en logout."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7d00141f-c119-4a05-8a21-72cbae719de7
  modified: 2026-07-23T15:22:26.707Z
---

Endurecimiento de seguridad PHI/PII implementado el 23 jul 2026 (Punto 2 del plan
de producción). Tres capas:

1. **Protección de pantalla** — `core/security/screen_security.dart` (`ScreenSecurity`,
   envuelve el paquete `screen_protector: ^1.5.3`). `enable()`: FLAG_SECURE (Android)
   + bloqueo de captura iOS + desenfoque en recientes. Idempotente, no lanza, guarda
   `kIsWeb`. Se activa en `TabShell.initState` (cubre TODOS los ingresos: login, PIN,
   restore) y se desactiva en logout. API real del paquete: `preventScreenshotOn/Off`,
   `protectDataLeakageWithBlur/Off`. ⚠️ NO verificado en dispositivo (es canal nativo;
   no se puede unit-testear). Verificar en Android/iOS reales.

2. **Enmascarado de logs** — `core/utils/log_sanitizer.dart` (`LogSanitizer.scrub`).
   Corre en TODO `AppLogger` (info/warn/error, incluido el objeto err) y en los
   `debugPrint` crudos de `ApiClient` y `ProgramacionService` (que registraban URLs,
   `raw response`, grupo-familiar con CI). Enmascara Bearer/Basic/JWT, campos
   token/password, y CI por CLAVE etiquetada (`ci`/`cedula`/`nrodoc`/`carnet` con
   comilla de cierre, así `ciudad` y números de ticket NO se tocan). 11 tests en
   `test/core/log_sanitizer_test.dart`. Nota: `AppLogger` ya es kDebugMode-only, esto
   es defensa en profundidad.

3. **Sandbox de PDFs** — `core/services/secure_docs_store.dart` (`SecureDocsStore`).
   `save()` guarda en `getApplicationDocumentsDirectory()/documentos_generados`
   (privado, nombre saneado contra path traversal). `wipeAll()` borra ese subdir y
   se llama en logout desde los DOS caminos de UI (`perfil_screen`,
   `local_auth_screen`) y desde `AuthRepository.logout()`. `document_preview_screen`
   ya usa `SecureDocsStore.save` (antes escribía en la raíz de documentos).

Detalle clave: el logout está FRAGMENTADO — la UI usa `TokenStorage.wipeAll()` +
`UserSession.clear()` directamente (NO `AuthRepository.logout()`, que existe pero la
UI no lo llama). Por eso la limpieza se cableó en los 3 sitios. Suite: 85/85 verde.
Relacionado: [[tests-binding-secure-storage]], CLAUDE.md sección Security Layer.
