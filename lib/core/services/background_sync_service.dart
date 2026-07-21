import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../storage/token_storage.dart';
import '../utils/app_logger.dart';
import 'appointment_status_sync.dart';
import 'notification_initializer.dart';
import 'session_restore_service.dart';

const _uniqueTaskName = 'cossmil_appointment_sync';
const _taskName = 'checkAppointmentStatus';

/// Punto de entrada invocado por el sistema operativo (Android WorkManager)
/// cuando corresponde ejecutar la tarea periódica — corre en un isolate
/// nuevo y aislado, sin nada del estado de la app en memoria (por eso
/// restaura la sesión desde secure storage en vez de usar [UserSession]
/// directamente).
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (!await TokenStorage.hasToken()) return true;
      await SessionRestoreService.restoreUserSession();
      await NotificationInitializer.initialize();
      await AppointmentStatusSync.checkCompletedAppointments();
    } catch (_) {
      // Best-effort: nunca reportar fallo (evita reintentos con backoff
      // por un chequeo que de por sí ya se repite cada 15 min).
    }
    return true;
  });
}

/// "Push sin Firebase": mientras haya sesión guardada, revisa cada ~15 min
/// (mínimo que permite Android para trabajo periódico) si alguna cita
/// cambió de estado en el backend — hoy solo detecta «Completado» → ofrece
/// calificación, la misma regla que [AppointmentStatusSync] aplica en
/// primer plano — pero SIN necesitar que el usuario abra la app.
///
/// Solo Android: no hay equivalente confiable en iOS/web con la
/// configuración actual del proyecto (iOS requiere entitlements de
/// Background Fetch que este proyecto no tiene habilitados).
class BackgroundSyncService {
  BackgroundSyncService._();

  static const _tag = 'BackgroundSyncService';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid || _initialized) return;
    try {
      await Workmanager().initialize(backgroundSyncDispatcher);
      _initialized = true;
      AppLogger.info(_tag, 'WorkManager initialized');
    } catch (e) {
      AppLogger.error(_tag, 'initialize failed', e, null);
    }
  }

  /// Agenda (o confirma) el chequeo periódico. Idempotente — `keep` no
  /// reemplaza el trabajo ya agendado, así que es seguro llamarlo en cada
  /// login/restauración de sesión sin reiniciar el conteo de 15 min.
  static Future<void> schedulePeriodicSync() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await initialize();
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      AppLogger.info(_tag, 'Periodic sync scheduled (every 15 min)');
    } catch (e) {
      AppLogger.error(_tag, 'schedulePeriodicSync failed', e, null);
    }
  }

  /// Cancela el chequeo periódico (logout — no tiene sentido seguir
  /// consultando el backend sin una sesión activa).
  static Future<void> cancel() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await Workmanager().cancelByUniqueName(_uniqueTaskName);
      AppLogger.debug(_tag, 'Periodic sync cancelled');
    } catch (e) {
      AppLogger.error(_tag, 'cancel failed', e, null);
    }
  }
}
