---
name: offline-cache-resiliencia
description: "Resiliencia offline — caché de lectura cifrada de citas y grupo familiar, OfflineBanner, y postura de escrituras solo-online."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7d00141f-c119-4a05-8a21-72cbae719de7
  modified: 2026-07-23T20:10:14.293Z
---

Resiliencia offline (Punto 3 del plan de producción), implementada el 23 jul 2026.

**Decisión de arquitectura (aprobada por el usuario):**
- **Storage: flutter_secure_storage vía `ISecureStorageService`** (mismo backend
  cifrado `cossmil_secure_prefs`). NO shared_preferences/hive/sqflite: las citas
  y el grupo familiar son PHI → deben ir cifrados; el volumen es pequeño → blob
  JSON basta; cero dependencias nuevas.
- **Escrituras SOLO online** (cancelar/crear cita). NO se encolan mutaciones:
  en contexto médico con ventanas de tiempo (backend rechaza cancelaciones
  "fuera del plazo de 06:00"), un replay diferido es riesgo de negocio. Bloquear
  con mensaje, no encolar.

**Piezas:**
- `core/data/citas_cache.dart` — `CitasCache` (buckets `historial`/`cancelados`,
  por `idper`) + `CachedCitas{reservas, savedAt, age}`. Round-trip con
  `ReservaModel.toCacheMap()/fromCacheMap()` (NO reusar fromJson: normaliza
  claves del backend).
- `core/data/grupo_familiar_cache.dart` — `GrupoFamiliarCache` (por `idper`
  titular). Round-trip: `BeneficiaryModel.toJson()` (ya existía) +
  `fromCacheMap()` NUEVO (fromJson perdía la foto: lee `foto`/`foto_base64`, no
  `photoBase64`).
- `core/utils/error_mapper.dart` — `ErrorMapper.isOffline(error)`: detecta
  SocketException/TimeoutException Y el texto con que ApiClient envuelve la red
  ("No se pudo conectar al servidor.", statusCode 0), que el mapeo por texto
  perdía.
- `core/widgets/offline_banner.dart` — `OfflineBanner(updatedAt)`: ámbar tenue
  (AppColors.warning), "Modo sin conexión · actualizado hace X", liveRegion.

**Wiring:**
- `reservas_screen`: read-through en `_fetchReservas` y `_fetchReservasForIdper`
  (éxito → guarda caché + `_isOffline=false`; error de red → lee caché →
  `_isOffline=true`+banner; sin caché → error/Reintentar). Offline APAGA la
  paginación de RED ("Cargar más historial") y el filtro "Cancelado" (otro
  endpoint); el "Mostrar más" client-side y los filtros Todos/Completado/Falta
  siguen (operan sobre `_history` en memoria).
- `InitialDataOrchestrator._loadGrupoFamiliar`: guarda en éxito, cae a caché si
  `isOffline`. Constructor acepta `GrupoFamiliarCache?` inyectable.
- Logout (`AuthRepository.logout`): `CitasCache().clearAll()` +
  `GrupoFamiliarCache().clearAll()`. Los 2 paths de UI ya usan
  `TokenStorage.wipeAll()`=deleteAll (nuke total), así que también limpian.

Tests: `test/core/citas_cache_test.dart` (11) + `grupo_familiar_cache_test.dart`
(6). Suite total 101/101 verde. Relacionado: [[phi-hardening-seguridad]],
[[tests-binding-secure-storage]].
