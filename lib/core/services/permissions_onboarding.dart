import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import 'location_service.dart';
import 'notification_service.dart';

/// Solicita los permisos del sistema UNA sola vez en la vida de la instalación.
///
/// Pide notificaciones y ubicación en el primer arranque exitoso y guarda un
/// flag persistente. En inicios posteriores no vuelve a pedir nada, aunque el
/// usuario los haya denegado (para no molestar; podrá habilitarlos desde los
/// Ajustes del sistema si lo desea).
///
/// La exención de optimización de batería se retiró a propósito: es el diálogo
/// más intrusivo y Google Play restringe `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
/// Los recordatorios locales funcionan sin él en la gran mayoría de equipos.
class PermissionsOnboarding {
  PermissionsOnboarding._();

  static const _tag = 'PermissionsOnboarding';

  /// Versionada (`_v1`) por si en el futuro se quiere volver a pedir permisos
  /// nuevos sin reutilizar el flag anterior.
  static const _kDone = 'perm_onboarding_done_v1';

  /// Solicita notificaciones + ubicación una única vez. Idempotente: en
  /// arranques posteriores retorna de inmediato sin mostrar diálogos.
  static Future<void> runOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kDone) ?? false) {
        AppLogger.debug(_tag, 'Permisos ya solicitados antes — se omite');
        return;
      }

      // 1) Notificaciones (Android 13+). Solo si aún no están habilitadas.
      if (!await NotificationService.areNotificationsEnabled()) {
        await NotificationService.requestPermissions();
      }

      // 2) Ubicación — para ordenar los hospitales por cercanía. Se pide el
      //    permiso aunque el GPS esté apagado (el usuario puede activarlo luego).
      await LocationService().requestPermissionOnly();

      await prefs.setBool(_kDone, true);
      AppLogger.info(
        _tag,
        'Permisos solicitados por primera vez — flag guardado',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'runOnce failed', e, st);
    }
  }
}
