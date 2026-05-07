# Análisis UX/UI + Arquitectura — COSSMIL App (v2)

> Fecha de análisis: 2026-05-04 (actualizado)
> Rama: `Solucionalo`
> Estado: 115 archivos `.dart`, 30 pantallas, 0 `Semantics()`, 102 `debugPrint`, 13 archivos con widgets Material, **2 tests**, **50+ `catch (_) {}` silenciosos**.

---

## TL;DR — Top 7 prioridades

| # | Problema | Impacto | Esfuerzo |
|---|----------|---------|----------|
| **A1** | `InitialDataOrchestrator` stubbed con `Future.delayed` → `LoadingDataScreen` es teatro UI puro. | 🔴 Crítico | Medio |
| **A2** | `BookingState` mutable compartido sin protección — race conditions en navegación rápida. | 🔴 Alto | Alto |
| **A3** | **Cero `Semantics()`** en toda la app — TalkBack/VoiceOver inutilizable. Obligación legal. | 🔴 Alto | Medio |
| **A4** | **Solo 2 tests** para 115 archivos. Cobertura ~0%. Cualquier refactor es un riesgo ciego. | 🔴 Crítico | Alto |
| **A5** | **50+ `catch (_) {}`** — errores tragados silenciosamente. Bugs invisibles en producción. | 🔴 Alto | Medio |
| **A6** | 6 pasos para reservar con solo 2 hospitales. Funnel inflado → pierde usuarios. | 🟠 Alto | Medio |
| **A7** | Mezcla Cupertino/Material en 13 archivos → look inconsistente. | 🟠 Medio | Bajo |

---

## 0. CRÍTICO — Arquitectura & Estado

| # | Problema | Archivo | Impacto |
|---|----------|---------|---------|
| 0.1 | ~~**`InitialDataOrchestrator` no carga nada.**~~ ✅ **RESUELTO** — carga real con `Future.wait`. | `initial_data_orchestrator.dart` | ✅ |
| 0.2 | ~~**Refetch redundante**~~ ✅ **RESUELTO** — `reservas_screen`, `calendario_hospital_screen` y `regional_screen` consumen `AppSessionCache` con fallback al API. | varios | ✅ |
| 0.3 | ~~**`BookingState` mutable compartido**~~ ✅ **RESUELTO** — `atomicUpdate()` con mutex en `tab_shell.dart`. | `tab_shell.dart` | ✅ |
| 0.4 | ~~**`magic_nav_bar.dart` código muerto**~~ ✅ **ELIMINADO** — archivo suprimido. | — | ✅ |
| 0.5 | ~~**`AppConfig.appVersion` hardcoded**~~ ✅ **RESUELTO** — `AppVersionHelper` lee `PackageInfo` en runtime; usado en `perfil_screen`, `loading_data_screen` y `programacion_service`. | `app_version_helper.dart` | ✅ |
| 0.6 | ~~**3 pantallas de transición**~~ ✅ **RESUELTO** — `loading_data_screen` ya no existe. | — | ✅ |
| 0.7 | ~~**`booking_service.dart` stub**~~ ✅ **ELIMINADO** — archivo suprimido. | — | ✅ |

---

## 1. ARQUITECTURA DE INFORMACIÓN & NAVEGACIÓN

| # | Problema | Impacto |
|---|----------|---------|
| 1.1 | ~~"Calendario de Atención" fuera del tab shell.~~ ✅ **RESUELTO** | ✅ |
| 1.2 | ~~**6 pasos** para 2 hospitales habilitados.~~ ✅ **RESUELTO** — `RegionalScreen` ahora muestra una lista flat de hospitales (regional como subtítulo, ordenados por proximidad), eliminando el sub-paso de acordeón. | ✅ |
| 1.3 | ~~**3 mecanismos de navegación** distintos desde Home grid.~~ ✅ **RESUELTO** — todas las acciones de Home pasan por `tabShell.goToTab` o el nuevo helper `tabShell.openSubRoute(...)`. | ✅ |
| 1.4 | ~~**`AppPageRoute` vs `CupertinoPageRoute` mezclados.**~~ ✅ **RESUELTO** — todas las pantallas usan `AppPageRoute`. | ✅ |
| 1.5 | ~~**`previousPageTitle` inconsistente** en flujo Calendario.~~ ✅ **RESUELTO** — la cadena Calendario → Especialidades → `<especialidad>` → Agenda alinea cada `previousPageTitle` con el `middle` de la pantalla previa. | ✅ |

---

## 2. HOME SCREEN

| # | Problema | Impacto |
|---|----------|---------|
| 2.1 | ~~Título **"Menú Principal"**~~ ✅ **RESUELTO** — ahora `"Inicio"`. | ✅ |
| 2.2 | **"Procedimientos COSSMIL"** con badge `'PRÓXIMAMENTE 👷'` + `Banner` Material. **Restaurado por solicitud** — debe verse igual que producción. | Medio |
| 2.3 | ~~**`ProfileCard` sin affordance**~~ ✅ **RESUELTO** — chevron añadido en esquina superior derecha cuando hay `onTap`. | ✅ |
| 2.4 | ~~News rows sin `OptimizedPressButton`~~ ✅ **RESUELTO** — filas y "Ver todos los comunicados" envueltos en `OptimizedPressButton`. | ✅ |
| 2.5 | ~~**Banner de horario truncado**~~ ✅ **RESUELTO** — eliminado `maxLines: 2 + ellipsis`; texto completo con `height: 1.35`. | ✅ |
| 2.6 | ~~Action cards `fontWeight: w900`~~ ✅ **RESUELTO** — bajado a `w700` para mejor jerarquía. | ✅ |
| 2.7 | ~~**Cargas async sin dispose cancellation**~~ ✅ **RESUELTO** — `_loadNews()` envuelto en try/catch, con guard `mounted` antes de cada `setState`. | ✅ |
| 2.8 | ~~Card del banner se reconstruye sin memoización~~ ✅ **RESUELTO** — extraído como `_HorarioBanner` `StatelessWidget` con props inmutables. | ✅ |

---

## 3. FLUJO DE RESERVA

| # | Problema | Impacto |
|---|----------|---------|
| 3.1 | ~~**Acordeón de 1-2 regionales** excesivo.~~ ✅ **RESUELTO** (vía 1.2) — `RegionalScreen` es lista flat. | ✅ |
| 3.2 | ~~Loading dialog sin texto~~ ✅ **RESUELTO** — nuevo `LoaderWithMessage` con copy específico ("Verificando disponibilidad…", "Cargando familiares…", "Verificando horario de atención…", "Comprobando citas activas…"). | ✅ |
| 3.3 | ~~Error state de `RegionalScreen`~~ ✅ **RESUELTO** — usa `AppStateWidget.error` con título y `onRetry`. | ✅ |
| 3.4 | ~~Beneficiarios no-titular sin nota~~ ✅ **RESUELTO** — banner informativo explica que solo pueden reservar para sí mismos. | ✅ |
| 3.5 | ~~`SpecialtyScreen` no explica interconsulta~~ ✅ **RESUELTO** — banner contextual antes de la sección "INTERCONSULTA (HABILITADAS)". | ✅ |
| 3.6 | ~~`AgendaScreen` refetchea `getFechaServidor()`~~ ✅ **RESUELTO** — consume `AppSessionCache.fechaServidor` cuando está poblado. | ✅ |
| 3.7 | ~~**`ScheduleScreen` polling c/15s sin pausar**~~ ✅ **RESUELTO** — `WidgetsBindingObserver` pausa en background; `tabShell.currentTabIndex` pausa al cambiar de tab. Refresh inmediato al volver. | ✅ |
| 3.8 | ~~Empty state confuso~~ ✅ **RESUELTO** — `_buildEmptyState()` distingue 4 escenarios (sin horarios cargados / fichas agotadas / jornada terminada / sin fichas) con copy específico y CTA "Cambiar de fecha". | ✅ |
| 3.9 | ~~**`allowedIdsuc` hardcoded**~~ ✅ **RESUELTO** — centralizado en `AppConfig.allowedHospitalIds`; `RegionalScreen` y `CalendarioHospitalScreen` lo consumen del mismo punto. | ✅ |

---

## 4. SUMMARY SCREEN (Confirmación)

| # | Problema | Impacto |
|---|----------|---------|
| 4.1 | ~~**Auto-scroll al botón a los 450ms**~~ ✅ **RESUELTO** — eliminado el auto-scroll inicial y el post-confirm. El usuario ahora ve el resumen completo desde arriba. | ✅ |
| 4.2 | ~~**Pulse infinito** del botón~~ ✅ **RESUELTO** — `_pulseOnce()` ejecuta un único ciclo (forward + reverse) y respeta `MediaQuery.disableAnimations`. | ✅ |
| 4.3 | ~~**Base64 decodificado en cada rebuild**~~ ✅ **RESUELTO** — `_decodePhoto` cachea `Uint8List` por string en `_decodedPhotos`. | ✅ |
| 4.4 | ~~**`crearCita` payload sin validar**~~ ✅ **RESUELTO** — `_missingBookingField()` verifica los 8 campos críticos pre-flight; si falta alguno, alerta al usuario y aborta antes del HTTP. | ✅ |
| 4.5 | ~~PDF preview sin caché de bytes~~ ✅ **RESUELTO** — `_cachedPdfBytes` evita re-descargas si el usuario abre y cierra el preview. | ✅ |

---

## 5. RESERVAS SCREEN

| # | Problema | Impacto |
|---|----------|---------|
| 5.1 | **3 filtros simultáneos** — carga cognitiva alta. Consolidar en sheet. | Medio |
| 5.2 | **`_initialPageSize = 999`** — trae 999 registros para mostrar 10. | Medio |
| 5.3 | **Búsqueda sin debounce** — cada keystroke recalcula 999 items. | Medio |
| 5.4 | Doble fetch al cambiar chip de cancelados. | Bajo |
| 5.5 | **`_loadPendingRatings` loop secuencial** — N llamadas async una por una. | Medio |
| 5.6 | `_buildLatestCard` y `_buildHistoryItem` repiten ~300 líneas. | Bajo |
| 5.7 | `DoctorRatingModal` sin CTA visible. | Bajo |
| 5.8 | Scroll position se pierde al cambiar filtro. | Bajo |

---

## 6. CALENDARIO DE ATENCIÓN

| # | Problema | Impacto |
|---|----------|---------|
| 6.1 | Falta banner persistente `"Solo consulta — no agenda citas"` en cada paso. | Alto |
| 6.2 | `cuposAse` disponible pero no se muestra en `DoctorScheduleScreen`. | Alto |
| 6.3 | `_kAllowedIdsuc` duplicado en 2 archivos. Centralizar en `AppConfig`. | Bajo |
| 6.4 | Lógica de búsqueda casi idéntica al flujo de reserva. Extraer widget reutilizable. | Bajo |

---

## 7. CONSISTENCIA DE PLATAFORMA (Cupertino vs Material)

| # | Problema | Archivo |
|---|----------|---------|
| 7.1 | `regional_screen.dart` usa Material `Icons.*`. | `regional_screen.dart` |
| 7.2 | `RefreshIndicator` Material. Cambiar por `CupertinoSliverRefreshControl`. | `regional_screen.dart` |
| 7.3 | `Banner` Material para badge "PRÓXIMAMENTE". | `home_screen.dart` |
| 7.4 | **13+ archivos** mezclan `SnackBar`, `RefreshIndicator`, `Material()`, `Icons.*`. | varios |
| 7.5 | `ScaffoldMessenger.showSnackBar` en Cupertino app. | varios |

---

## 8. ACCESIBILIDAD

| # | Problema | Estado |
|---|----------|--------|
| 8.1 | **Cero `Semantics()`** en toda la app. | 🔴 Crítico |
| 8.2 | Dot de color sin texto alternativo — daltónicos no distinguen. | Medio |
| 8.3 | Animaciones no respetan `MediaQuery.disableAnimations`. | Medio |
| 8.4 | Touch targets < 44pt en News rows. | Bajo |
| 8.5 | Contrast ratio sin auditar — `textTertiary` puede ser < 4.5:1. | Medio |
| 8.6 | Inputs sin `TextInputAction.next`. | Bajo |

---

## 9. PERFORMANCE & BATERÍA

| # | Problema | Archivo |
|---|----------|---------|
| 9.1 | `LoginScreen._floatCtrl.repeat()` — flotación infinita del logo. | `login_screen.dart` |
| 9.2 | `SplashScreen` — 5 controllers, ~12 animaciones en paralelo. | `splash_screen.dart` |
| 9.3 | `SummaryScreen._pulseCtrl..repeat()` — pulse infinito. | `summary_screen.dart` |
| 9.4 | `ScheduleScreen._refreshTimer` sin pausar en background. | `schedule_screen.dart` |
| 9.5 | **Base64 decodificación en `build()`** — sin caché. | varios |
| 9.6 | `InitialDataOrchestrator` timeout es teatro — stubs tardan <1s. | `initial_data_orchestrator.dart` |
| 9.7 | Muchos widgets sin `const` reconstruidos innecesariamente. | `home_screen.dart` |

---

## 10. CALIDAD DE CÓDIGO

| # | Problema | Detalle |
|---|----------|---------|
| 10.1 | **102 `debugPrint`** en 15 archivos — usar `AppLogger`. | varios |
| 10.2 | **EdgeInsets hardcoded** (~81 ocurrencias top-10). | varios |
| 10.3 | **`Color(0xFF...)` hardcoded** (~108 ocurrencias). | varios |
| 10.4 | Parsing duplicado de fotos médico (bytes+base64) en 3+ archivos. | varios |
| 10.5 | `_fetchReservas` y `_fetchReservasForIdper` — 60 líneas duplicadas. | `reservas_screen.dart` |
| 10.6 | `InfoBanner` reimplementado en cada pantalla con copy-paste. | varios |
| 10.7 | Comentarios redundantes mezclados español/inglés. | varios |
| 10.8 | `magic_nav_bar.dart` no se importa. Eliminar. | `magic_nav_bar.dart` |
| 10.9 | `PerfilScreen._saveEmail()` no valida formato. | `perfil_screen.dart` |

---

## 11. SEGURIDAD

| # | Problema | Detalle |
|---|----------|---------|
| 11.1 | Validación de password solo en cliente. Verificar backend. | `perfil_screen.dart` |
| 11.2 | `debugPrint` filtra `crearCita payload` con datos sensibles. | `summary_screen.dart` |
| 11.3 | `api_client.dart` loguea URLs completas con IDs sensibles. | `api_client.dart` |
| 11.4 | Inactividad de 2 min muy corta. Apps similares usan 5-10 min. | `security_service.dart` |

---

## 12. NUEVOS HALLAZGOS (v2)

| # | Problema | Detalle | Impacto |
|---|----------|---------|---------|
| 12.1 | **Solo 2 tests** (`widget_test.dart` + `responsive_layout_test.dart`). Cobertura ~0%. | `test/` | 🔴 Crítico |
| 12.2 | **50+ `catch (_) {}` silenciosos** — errores tragados sin log. Top offenders: `reservas_screen` (8), `schedule_screen` (5), `summary_screen` (6), `tab_shell` (5). | varios | 🔴 Alto |
| 12.3 | **`tab_shell.dart` = 1099 líneas God Class** — mezcla seguridad, horarios, booking state, navegación, lifecycle, biometría. Extraer `SecurityMixin`, `HorarioChecker`, etc. | `tab_shell.dart` | 🟠 Alto |
| 12.4 | **`reservas_screen.dart` = 1627 líneas God Widget** — filtros, fetch, ratings, avatars, cancelación en un solo archivo. Descomponer. | `reservas_screen.dart` | 🟠 Alto |
| 12.5 | **`analysis_options.yaml` sin reglas activas** — solo `flutter_lints` base. Falta `avoid_print`, `prefer_const_constructors`, `always_use_package_imports`, `cancel_subscriptions`. | `analysis_options.yaml` | 🟠 Medio |
| 12.6 | **`pubspec.yaml` name = `flutter_application_1`** — nombre genérico. Cambiar a `cossmil_app`. | `pubspec.yaml` | 🟢 Bajo |
| 12.7 | **`booking_service.dart` (1.9KB) servicio muerto** — un solo método stub con `TODO`. | `booking_service.dart` | 🟠 Medio |
| 12.8 | **`ApiClient` nunca cierra conexiones** — `close()` existe pero no se llama. Leak de sockets. | `api_client.dart` | 🟠 Medio |
| 12.9 | **`notification_service.dart` = 986 líneas God Class** — channels, scheduling, ratings, tab switching en uno. | `notification_service.dart` | 🟠 Medio |
| 12.10 | **`perfil_screen.dart` = 1283 líneas** — perfil + cambio password + emergencia + logout en un archivo. | `perfil_screen.dart` | 🟠 Medio |
| 12.11 | **17 `rootNavigator: true`** dispersos — patrón frágil, un pop incorrecto mata el shell. Centralizar en un helper. | varios | 🟠 Medio |
| 12.12 | **`ApiClient._doPost` loguea body completo** incluyendo payloads sensibles en debug. | `api_client.dart` L149 | 🟠 Medio |

---

## PLAN DE MEJORA — PRIORIZADO (v2)

### Sprint 1 — Quick wins (1-2 días) — *bajo esfuerzo, alto valor*

- [ ] **7.1** Reemplazar Material Icons por `CupertinoIcons` en `regional_screen.dart`
- [ ] **7.2** `RefreshIndicator` → `CupertinoSliverRefreshControl` en `regional_screen.dart`
- [ ] **7.3** Reemplazar `Banner` Material por overlay Cupertino en `home_screen.dart`
- [ ] **3.3** Usar `AppStateWidget` en error de `RegionalScreen`
- [ ] **4.1** Eliminar auto-scroll a botón en `SummaryScreen`
- [ ] **4.2** Cambiar pulse a un solo ciclo (no `.repeat()`)
- [ ] **2.2** Ocultar "Procedimientos COSSMIL" hasta implementarlo
- [ ] **2.4** Envolver news rows en `OptimizedPressButton`
- [ ] **2.6** Bajar `fontWeight` de `w900` → `w700` en action cards
- [ ] **0.4 / 10.8** Eliminar `magic_nav_bar.dart` (~250 líneas muertas)
- [ ] **12.6** Renombrar `flutter_application_1` → `cossmil_app` en pubspec.yaml

### Sprint 2 — UX impactante (2-3 días)

- [ ] **A6 / 1.2 / 3.1** Fusionar Regional+Hospital: flat list de 2 cards (elimina 1 paso)
- [ ] **3.2** Texto en dialog: `"Verificando disponibilidad…"`
- [ ] **6.1** Banner persistente `"Solo consulta — no agenda citas"` en Calendario
- [ ] **6.2** Mostrar `cuposAse` en `DoctorScheduleScreen`
- [ ] **5.1** Consolidar 3 filtros de `ReservasScreen` en bottom sheet único
- [ ] **5.3** Debounce 200ms en search de `ReservasScreen`
- [ ] **2.3** Chevron/affordance en `ProfileCard`
- [ ] **3.7 / 9.4** Pausar `_refreshTimer` en background/tab change
- [ ] **3.4** Tooltip explicando restricción de beneficiarios no-titular

### Sprint 3 — Arquitectura & Errores (3-5 días) — *fundacional*

- [ ] **0.1 / 9.6** Implementar los 4 `_load*` reales en `InitialDataOrchestrator`
- [ ] **0.2** Consumir `AppSessionCache` desde pantallas (eliminar refetch)
- [ ] **0.6** Si precarga toma <300ms, eliminar `LoadingDataScreen`
- [ ] **12.2** **Auditar 50+ `catch (_) {}`** — reemplazar por `catch (e) { AppLogger.warn(...) }` o propagar
- [ ] **6.3 / 3.9** Centralizar `_kAllowedIdsuc` en `AppConfig.allowedHospitalIds`
- [ ] **1.4** Normalizar transiciones a `AppPageRoute`
- [ ] **5.2** Paginación real en `ReservasScreen` (eliminar `_initialPageSize=999`)
- [ ] **10.4** Crear `core/utils/photo_codec.dart` reutilizable
- [ ] **10.5** Refactor `_fetchReservas` duplicado
- [ ] **10.6** Crear `core/widgets/info_banner.dart` reutilizable
- [ ] **0.7 / 12.7** Eliminar o implementar `booking_service.dart` stub
- [ ] **12.8** Gestionar lifecycle de `ApiClient` — singleton con dispose en logout

### Sprint 4 — Descomposición de God Classes (3-4 días)

- [ ] **12.3** Extraer de `tab_shell.dart` (1099 líneas):
  - `SecurityLifecycleMixin` (inactividad, lock, biometría) → ~250 líneas
  - `HorarioChecker` (verificación horarios) → ~100 líneas
  - `BookingTabGuard` (lógica `_tryEnterBookingTab`) → ~150 líneas
- [ ] **12.4** Descomponer `reservas_screen.dart` (1627 líneas):
  - `ReservasFilterSheet` (filtros + search) → widget separado
  - `ReservaCard` (layout de card compartido) → reemplaza `_buildLatestCard` + `_buildHistoryItem`
  - `ReservasDataController` (fetch + cache) → lógica extraída
- [ ] **12.9** Dividir `notification_service.dart` (986 líneas):
  - `NotificationChannelManager` (channels + permisos)
  - `AppointmentReminder` (scheduling de citas)
  - `RatingNotifier` (calificación post-cita)
- [ ] **12.10** Dividir `perfil_screen.dart` (1283 líneas):
  - `PasswordChangeSheet` → widget separado
  - `ProfilePhotoSection` → widget separado
- [ ] **12.11** Crear `core/helpers/root_navigator.dart` helper para centralizar `rootNavigator: true`

### Sprint 5 — Accesibilidad (2-3 días)

- [ ] **8.1** `Semantics` en 30+ widgets críticos (news, cards, chips, modales)
- [ ] **8.2** Texto alternativo en dot de color de noticias
- [ ] **8.3** Respetar `MediaQuery.disableAnimations` en pulse, float, ripples
- [ ] **8.5** Auditar contrast ratio WCAG AA (4.5:1) en `textTertiary`/`textSecondary`
- [ ] **8.6** `TextInputAction.next` + `FocusNode` en Login y Perfil
- [ ] **2.5** Banner de horario sin truncar
- [ ] **2.1** "Menú Principal" → `"Inicio"` o saludo contextual

### Sprint 6 — Performance (1-2 días)

- [ ] **9.1 / 9.2** Reducir animaciones infinitas en Login/Splash
- [ ] **9.5 / 4.3** Cachear `Uint8List` decodificado en estado (summary, reservas, detalle)
- [ ] **9.7** Convertir build-methods en widgets `const` con state hoisted
- [ ] **5.5** `Future.wait` para `_loadPendingRatings`

### Sprint 7 — Testing (continuo, iniciar en paralelo) — *NUEVO*

- [ ] **12.1** Tests unitarios para servicios críticos:
  - `auth_service.dart` — login/logout/refresh flows
  - `programacion_service.dart` — parsing de respuestas API
  - `api_client.dart` — retry logic, 401 refresh, error handling
  - `security_service.dart` — inactividad, PIN, biometría
- [ ] **12.1** Tests de widget para flujos críticos:
  - `BookingFlowScreen` — navegación entre pasos
  - `LoginScreen` — validación, error states
  - `SummaryScreen` — payload validation pre-flight
- [ ] **12.1** Configurar CI mínimo: `flutter analyze` + `flutter test` en pre-push hook

### Sprint 8 — Calidad / Higiene (continuo)

- [ ] **10.1** Reemplazar 102 `debugPrint` por `AppLogger` en 15 archivos
- [ ] **10.2** Migrar `EdgeInsets` hardcoded a tokens `r.spaceXs..xxl`
- [ ] **10.3** Migrar `Color(0xFF...)` a `AppColors.*`
- [ ] **10.7** Limpiar comentarios redundantes
- [ ] **10.9** Validar formato de email en `PerfilScreen._saveEmail`
- [ ] **0.5** `PackageInfo` en vez de `AppConfig.appVersion` hardcoded
- [ ] **11.2 / 12.12** Sanitizar logs de payloads sensibles
- [ ] **12.5** Endurecer `analysis_options.yaml` con reglas activas

### Sprint 9 — Refactor de estado (alto esfuerzo) — *evaluar antes*

- [ ] **0.3 / A2** Mover `BookingState` a `ChangeNotifier` con flujos inmutables

---

## Archivos afectados por sprint

| Sprint | Archivos clave |
|--------|----------------|
| 1 | `regional_screen.dart`, `summary_screen.dart`, `home_screen.dart`, `magic_nav_bar.dart` (delete), `pubspec.yaml` |
| 2 | `regional_screen.dart`, `calendario_hospital_screen.dart`, `doctor_schedule_screen.dart`, `reservas_screen.dart`, `schedule_screen.dart`, `home_screen.dart` |
| 3 | `initial_data_orchestrator.dart`, `app_session_cache.dart`, `app_config.dart`, `loading_data_screen.dart`, `booking_service.dart`, `api_client.dart`, `core/utils/photo_codec.dart` (new), `core/widgets/info_banner.dart` (new), **50+ archivos con `catch (_)`** |
| 4 | `tab_shell.dart` (split), `reservas_screen.dart` (split), `notification_service.dart` (split), `perfil_screen.dart` (split), `core/helpers/root_navigator.dart` (new) |
| 5 | `home_screen.dart`, `summary_screen.dart`, `login_screen.dart`, `splash_screen.dart`, `perfil_screen.dart`, `app_colors.dart` |
| 6 | `login_screen.dart`, `splash_screen.dart`, `summary_screen.dart`, `reservas_screen.dart`, `home_screen.dart` |
| 7 | `test/` (new tests), `auth_service_test.dart`, `api_client_test.dart`, `booking_flow_test.dart`, CI config |
| 8 | 15 archivos con debugPrint, 14+ con Color hardcoded, `analysis_options.yaml` |
| 9 | `tab_shell.dart`, `booking_flow_screen.dart`, todas las pantallas de booking |

---

## Métricas de salud actuales

| Métrica | Valor actual | Objetivo |
|---------|-------------|----------|
| Archivos `.dart` | 115 | — |
| `Semantics()` widgets | **0** | ≥30 |
| `debugPrint` calls | **102** | 0 (usar `AppLogger`) |
| Archivos importando `material.dart` | 30 | ~5 (solo theming) |
| Widgets Material en features | 13 archivos | 0 |
| `Color(0xFF...)` hardcoded | ~108 ocurrencias | <20 |
| `EdgeInsets` magic numbers | ~81 en top-10 | <30 |
| `_kAllowedIdsuc` duplicaciones | 2 | 1 (en `AppConfig`) |
| Orchestrators stub | 1 (crítico) | 0 |
| Código muerto detectado | `magic_nav_bar.dart` + `booking_service.dart` stub | 0 |
| **Tests** | **2** | **≥40** |
| **`catch (_) {}` silenciosos** | **50+** | **<5** |
| **God Classes (>800 líneas)** | **5** (`tab_shell`, `reservas`, `perfil`, `notification`, `login`) | **0** |
| **Linter rules activas** | **0 custom** | **≥10** |
| **`rootNavigator: true` dispersos** | **17** | **centralizado en helper** |
