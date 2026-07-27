import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../utils/app_logger.dart';
import 'notification_ui.dart';

/// Gestiona la inicialización del plugin, canales Android y permisos en runtime.
///
/// El plugin compartido [plugin] es accedido por [NotificationScheduler].
class NotificationInitializer {
  NotificationInitializer._();

  static const _tag = 'NotificationInitializer';

  /// Plugin compartido con [NotificationScheduler].
  static final plugin = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ── Inicialización ─────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    if (_initialized) return;

    // Timezone para Bolivia (GMT-4)
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/La_Paz'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: NotificationUiHandler.onNotificationTap,
    );

    // Eliminar canales viejos (sin sonido custom) para que Android use los nuevos
    if (Platform.isAndroid) {
      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.deleteNotificationChannel('cossmil_booking');
      await androidPlugin?.deleteNotificationChannel('cossmil_reminder');
    }

    _initialized = true;
    AppLogger.info(_tag, 'Initialized — timezone: ${tz.local.name}');
  }

  // ── Permisos ───────────────────────────────────────────────────────────────

  /// Solicita POST_NOTIFICATIONS (Android 13+).
  /// DEBE llamarse DESPUÉS de runApp — nunca en main().
  static Future<bool> requestPermissions() async {
    try {
      await initialize();
      if (!Platform.isAndroid) return true;
      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? true;
      if (granted) {
        AppLogger.info(_tag, 'POST_NOTIFICATIONS: concedido');
      } else {
        AppLogger.warn(
          _tag,
          'POST_NOTIFICATIONS: DENEGADO — las notificaciones no llegarán',
        );
      }
      return granted;
    } catch (e, st) {
      AppLogger.error(_tag, 'requestPermissions failed', e, st);
      return false;
    }
  }

  /// Verifica si las notificaciones están habilitadas sin mostrar diálogos.
  static Future<bool> areNotificationsEnabled() async {
    try {
      await initialize();
      if (!Platform.isAndroid) return true;
      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Solicita exención de optimización de batería.
  /// CRÍTICO para Xiaomi (MIUI), Huawei (EMUI), Samsung (One UI).
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        AppLogger.info(_tag, 'Battery optimization exemption: $result');
      } else {
        AppLogger.debug(_tag, 'Battery optimization: ya exenta');
      }
    } catch (e) {
      AppLogger.error(
        _tag,
        'requestBatteryOptimizationExemption failed',
        e,
        null,
      );
    }
  }

  // ── Notificación que abrió la app (cold start) ─────────────────────────────

  static bool _launchNotificationConsumed = false;

  /// Si la app fue abierta tocando una notificación mientras estaba
  /// completamente cerrada (no en segundo plano), la entrega aquí.
  /// `onDidReceiveNotificationResponse` (registrado en [initialize]) NUNCA se
  /// dispara para ese caso — solo con la app ya corriendo en foreground o
  /// segundo plano — así que sin esto el tap que abrió la app se pierde en
  /// silencio (no aparece el modal ni cambia de pestaña).
  ///
  /// Llamar una vez que la sesión y la navegación ya están listas (ej. en
  /// `TabShellState.initState`, nunca desde `main()`).
  static Future<void> consumeAppLaunchNotification() async {
    if (_launchNotificationConsumed) return;
    _launchNotificationConsumed = true;
    try {
      final details = await plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (details?.didNotificationLaunchApp == true && response != null) {
        AppLogger.info(
          _tag,
          'App abierta desde el tap de una notificación — despachando',
        );
        NotificationUiHandler.onNotificationTap(response);
      }
    } catch (e) {
      AppLogger.warn(_tag, 'consumeAppLaunchNotification failed: $e');
    }
  }
}
