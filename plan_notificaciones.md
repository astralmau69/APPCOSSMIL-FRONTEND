# Plan de Mejora — Sistema de Notificaciones COSSMIL

> Fecha: 2026-05-07 | Archivo principal: `lib/core/services/notification_service.dart` (1,067 líneas)

---

## Estado Actual — ¿Qué tenemos?

### ✅ Lo que funciona bien

| Funcionalidad | Detalle |
|---|---|
| **Notificación de confirmación** | `showBookingConfirmed()` — se programa 5 min después de confirmar la cita |
| **5 recordatorios escalonados** | 2 días, 1 día, 3 horas, 30 min, 15 min antes de la cita |
| **Sonido personalizado** | `notificacion_cita.mp3` en Android (`res/raw/`) e iOS |
| **Canales separados** | `cossmil_booking_v2` (confirmaciones) y `cossmil_reminder_v2` (recordatorios) |
| **Fallback de scheduling** | `_scheduleWithFallback()` intenta `exactAllowWhileIdle` → `inexactAllowWhileIdle` |
| **AlarmClock para críticos** | Los recordatorios de 30 y 15 min usan `AndroidScheduleMode.alarmClock` |
| **Persistencia cross-session** | Datos de cita guardados en `FlutterSecureStorage` por usuario |
| **Re-scheduling al login** | `rescheduleNotificationsForCurrentUser()` re-programa tras reinicio |
| **Permisos Android 13+** | `POST_NOTIFICATIONS` + `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` |
| **Exención de batería** | `requestBatteryOptimizationExemption()` para Xiaomi/Huawei/Samsung |
| **Modal in-app al tap** | Dialog con datos de la cita + botón cancelar + sonido |
| **Validación de usuario** | Payload verifica `userId` contra sesión activa |
| **Cancelación al logout** | `cancelAllReminders()` limpia todo al cerrar sesión |
| **Boot receiver** | AndroidManifest registra `ScheduledNotificationBootReceiver` |
| **Calificación post-cita** | `DoctorRatingModal` con persistencia y auto-show ventana 15min–24h |

### 🔴 Problemas y Carencias Identificadas

| # | Problema | Severidad | Detalle |
|---|----------|-----------|---------|
| **N1** | **God Class: 1,067 líneas** | 🟠 Alto | Un solo archivo mezcla: inicialización, permisos, UI (modal 200 líneas), scheduling, persistencia, cancelación de citas HTTP, tab switching, ticket mapping. Viola SRP masivamente. |
| **N2** | **Sin notificaciones push** | 🔴 Crítico | Solo notificaciones locales. Si la app no está instalada/activa, el usuario no recibe nada. Sin Firebase/FCM. |
| **N3** | **Sin centro de notificaciones** | 🟠 Alto | No hay pantalla de historial de notificaciones. El usuario no puede ver notificaciones pasadas o pendientes. |
| **N4** | **Sin toggle por tipo** | 🟠 Medio | El usuario no puede elegir qué notificaciones recibir (recordatorios sí, confirmaciones no, etc.) |
| **N5** | **Sin notificación de calificación** | 🟠 Medio | El payload handler tiene `type == 'rating'` (L179) pero **nunca se programa** una notificación de calificación. Es código muerto. |
| **N6** | **Cancelación HTTP en UI service** | 🟠 Alto | `_executeCancelFromNotification()` hace llamadas HTTP a `ProgramacionService.cancelarCita()` directamente desde el servicio de notificaciones — mezcla responsabilidades. |
| **N7** | **Modal Material en app Cupertino** | 🟢 Bajo | `showGeneralDialog` usa `Material(color: transparent)` wrapper + `Theme.of` para detectar dark mode — inconsistente con el estilo Cupertino. |
| **N8** | **`_idFromTicket` colisiones** | 🟠 Medio | `(numeric % 99990) * 10 + suffix` puede colisionar si dos tickets tienen el mismo residuo mod 99990 (ej: ticket 100000 = ticket 10). |
| **N9** | **Sin distinción beneficiario/titular** | 🟠 Medio | Los recordatorios usan nombre del paciente pero no distinguen visualmente si es para un beneficiario vs titular. |
| **N10** | **Sin Cazador de Fichas** | 🟠 Alto | Feature planeada (workmanager + polling de agenda-medico-movil) pero **no implementada**. |
| **N11** | **Versión desactualizada** | 🟢 Info | `flutter_local_notifications: ^18.0.0` — disponible: 21.0.0. Hay 3 major versions de atraso. |
| **N12** | **Sin feedback visual de permisos** | 🟠 Medio | Si el usuario deniega permisos, no hay UI que explique el impacto ni un camino para reactivar desde Perfil. |

---

## Plan de Mejora — 4 Fases

---

### Fase 1 — Correcciones y Refactor
**Duración estimada: 2-3 días | Sin dependencia de backend**

> Objetivo: Limpiar el God Class, corregir bugs y subir la base de calidad.

#### 1.1 Dividir `notification_service.dart` en 4 archivos

Referencia: `cambios.md` item 12.9.

| Archivo | Responsabilidad | ~Líneas |
|---|---|---|
| `notification_initializer.dart` | `initialize()`, permisos, canales, timezone | ~120 |
| `notification_scheduler.dart` | Scheduling de citas, persistencia, re-scheduling, cancelación | ~450 |
| `notification_ui.dart` | Modal in-app, tap handler, tab switching, audio | ~200 |
| `notification_service.dart` | Fachada pública que delega a los 3 anteriores | ~80 |

#### 1.2 Correcciones específicas

- **N5 — Notificación de calificación:** Implementar `scheduleRatingReminder()` en `notification_scheduler.dart` que programa una notificación 2h después de la cita con `type: 'rating'` en el payload. El tap handler ya funciona (`_onSwitchTab(1)`).
- **N6 — HTTP en service:** Extraer la lógica de cancelación HTTP a un callback que `tab_shell` registre, similar al patrón de `_onSwitchTab`.
- **N7 — Modal Material:** Reemplazar `Material()` wrapper por `Container()` con `AppColors.cardBg(isDark)` y usar `CupertinoDialogAction` para los botones.
- **N8 — Hash de IDs:** Reemplazar `numeric % 99990` por un hash más robusto para evitar colisiones entre tickets.

#### 1.3 Archivos afectados

```
lib/core/services/notification_service.dart     → dividir
lib/core/services/notification_initializer.dart  → [NUEVO]
lib/core/services/notification_scheduler.dart    → [NUEVO]
lib/core/services/notification_ui.dart           → [NUEVO]
lib/core/services/notification_rating_scheduler.dart → [NUEVO]
lib/features/booking/screens/summary_screen.dart → actualizar imports
lib/features/loading/screens/loading_data_screen.dart → actualizar imports
lib/features/reservas/screens/reservas_screen.dart → actualizar imports
lib/shell/tab_shell.dart → actualizar imports + registrar callback de cancelación
```

#### 1.4 Verificación Fase 1

```bash
flutter analyze
flutter build apk --release
# Confirmar reserva → verificar 6 notificaciones programadas (5 recordatorios + 1 confirmación)
# Esperar 2h post-cita → verificar notificación de calificación
```

---

### Fase 2 — Centro de Notificaciones + Toggles
**Duración estimada: 3-4 días | Sin dependencia de backend**

> Objetivo: Dar al usuario visibilidad y control sobre sus notificaciones.

#### 2.1 Centro de Notificaciones

**Archivo nuevo:** `lib/features/notificaciones/screens/notificaciones_screen.dart`

- Lista cronológica: recordatorios, confirmaciones, calificaciones
- Estados: leída / no leída con indicador visual
- Tap → abre modal de detalle de cita o `DoctorRatingModal`
- Swipe to dismiss
- Persistencia en `FlutterSecureStorage` por usuario (historial últimos 30 días)

**Modelo nuevo:** `lib/core/models/app_notification.dart`

```dart
class AppNotification {
  final String id;
  final String type;          // 'reminder' | 'booking' | 'rating' | 'cazador'
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? payload;
}
```

#### 2.2 Toggles de preferencias

**Archivo nuevo:** `lib/core/services/notification_preferences.dart`

```dart
class NotificationPreferences {
  static Future<bool> getReminders();      // Recordatorios de cita
  static Future<bool> getConfirmations();  // Confirmación inmediata (5 min)
  static Future<bool> getRatings();        // Solicitud de calificación
  static Future<bool> getCazador();        // Cazador de Fichas
  // setters correspondientes persisten en SharedPreferences
}
```

El `notification_scheduler.dart` consultará estas preferencias antes de cada `_scheduleWithFallback()`.

#### 2.3 UI en Perfil y Home

**`perfil_screen.dart`:** Nueva sección "Notificaciones" con:
- Toggle "Recordatorios de citas"
- Toggle "Confirmación de reserva"
- Toggle "Solicitar calificación"
- Estado de permisos del sistema con botón "Abrir Configuración"
- Link "Ver todas mis notificaciones" → `NotificacionesScreen`

**`home_screen.dart`:** Ícono 🔔 en el header con badge de no leídas.

#### 2.4 Archivos afectados

```
lib/features/notificaciones/screens/notificaciones_screen.dart  → [NUEVO]
lib/core/models/app_notification.dart                            → [NUEVO]
lib/core/services/notification_preferences.dart                  → [NUEVO]
lib/features/perfil/screens/perfil_screen.dart                   → sección Notificaciones
lib/features/home/screens/home_screen.dart                       → badge campana
lib/core/services/notification_scheduler.dart                    → consumir prefs
```

---

### Fase 3 — Notificaciones Push (FCM)
**Duración estimada: 5-7 días | ⚠️ Requiere soporte en backend**

> Objetivo: Notificaciones que llegan aunque la app esté cerrada o sin instalar en primer plano.

> ⚠️ **BLOQUEANTE:** El backend debe implementar:
> - `POST /api/notificaciones/register-device` — recibir y guardar FCM token
> - `DELETE /api/notificaciones/unregister-device` — limpiar al logout
> - Infraestructura de envío (Firebase Admin SDK o similar)

#### 3.1 Dependencias a agregar

```yaml
# pubspec.yaml
firebase_core: ^3.x
firebase_messaging: ^15.x
```

#### 3.2 Archivos nuevos

```
lib/core/services/push_notification_service.dart  → registro FCM, handlers
android/app/google-services.json                  → config Firebase Android
ios/Runner/GoogleService-Info.plist               → config Firebase iOS
android/app/src/main/AndroidManifest.xml          → receptor de push
```

#### 3.3 Flujo

1. Login exitoso → `PushNotificationService.registerToken()` → `POST /api/notificaciones/register-device`
2. Backend envía push al token cuando hay eventos del sistema (cancelación de horario, cambio de consultorio, etc.)
3. `firebase_messaging` recibe → muestra notificación local vía `notification_ui.dart`
4. Logout → `PushNotificationService.unregisterToken()` → limpiar token del servidor

---

### Fase 4 — Cazador de Fichas
**Duración estimada: 4-5 días | Sin dependencia de backend**

> Objetivo: Monitorear en background la disponibilidad de citas para médicos favoritos y notificar al instante.

#### 4.1 Dependencias a agregar

```yaml
# pubspec.yaml
workmanager: ^0.5.x
```

#### 4.2 Flujo

1. Usuario marca médico como ⭐ favorito desde `AgendaScreen` o `DoctorScheduleScreen`
2. `workmanager` registra una tarea periódica (cada 15-30 min según configuración)
3. La tarea consulta `GET /api/programacion/agenda-medico-movil` para cada médico favorito
4. Si detecta slots disponibles → notificación local inmediata con sonido distinto
5. Respeta `NotificationPreferences.getCazador()`

#### 4.3 Archivos nuevos

```
lib/core/services/cazador_fichas_service.dart                → lógica de polling y favoritos
lib/features/booking/widgets/doctor_favorite_button.dart     → botón ⭐ en agenda
lib/features/notificaciones/screens/cazador_config_screen.dart → configuración
```

#### 4.4 Consideraciones

- El polling en background en Android está limitado por Doze Mode. `workmanager` maneja esto, pero la frecuencia mínima práctica es ~15 min.
- En iOS, las tareas en background son más restrictivas (`BGTaskScheduler`). `workmanager` 0.5+ lo soporta.
- Debe consumir `NotificationPreferences.getCazador()` — desactivado por defecto para no drenar batería sin consentimiento.

---

## Resumen de Esfuerzo

| Fase | Esfuerzo | Backend | Prioridad |
|------|----------|---------|-----------|
| **Fase 1** — Refactor + Fix notif. calificación | 2-3 días | ❌ No | 🔴 Inmediata |
| **Fase 2** — Centro de notificaciones + Toggles | 3-4 días | ❌ No | 🟠 Alta |
| **Fase 3** — Push (FCM) | 5-7 días | ✅ Sí | 🟡 Media |
| **Fase 4** — Cazador de Fichas | 4-5 días | ❌ No | 🟡 Media |

> 💡 **Recomendación:** Ejecutar Fase 1 + Fase 2 en un sprint de 5-7 días. Esto da valor inmediato al usuario (historial, toggles, calificación post-cita) sin depender del backend. Fases 3 y 4 se planifican en sprints posteriores según prioridad del producto.

---

## Métricas de éxito

| Métrica | Antes | Objetivo Fase 1+2 |
|---------|-------|-------------------|
| Líneas en `notification_service.dart` | 1,067 | < 100 (fachada) |
| God Classes de notificaciones | 1 | 0 |
| Notificación de calificación funcional | ❌ | ✅ |
| Control granular por tipo | ❌ | ✅ |
| Historial visible para el usuario | ❌ | ✅ |
| Colisiones de ID posibles | Sí | No |
| Modal 100% Cupertino | ❌ | ✅ |
