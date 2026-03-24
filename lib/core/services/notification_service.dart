import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../utils/app_logger.dart';

/// Servicio de notificaciones locales para citas médicas.
///
/// Uso:
///   - [initialize] — llamar en main() antes de runApp
///   - [showBookingConfirmed] — notificación inmediata al confirmar
///   - [scheduleAppointmentReminders] — programa 3 recordatorios futuros
///   - [cancelAppointmentReminders] — cancela los 3 por ticketId
class NotificationService {
  NotificationService._();

  static const _tag = 'NotificationService';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Inicialización ──────────────────────────────────────────────────────

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
    await _plugin.initialize(settings);

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    AppLogger.info(_tag, 'Initialized — timezone: ${tz.local.name}');
  }

  // ── Notificación inmediata al confirmar reserva ─────────────────────────

  static Future<void> showBookingConfirmed({
    required String especialidad,
    required String medico,
    required String fecha,
    required String hora,
    required String paciente,
    required String ticketNumber,
  }) async {
    try {
      await initialize();

      final androidDetails = AndroidNotificationDetails(
        'cossmil_booking',
        'Reservas COSSMIL',
        channelDescription: 'Confirmaciones de citas médicas',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF0C4A6E),
        styleInformation: BigTextStyleInformation(
          '$especialidad · $medico\n$fecha a las $hora',
          summaryText: 'Ficha $ticketNumber',
        ),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _plugin.show(
        _idFromTicket(ticketNumber, 9), // sufijo 9 = confirmación inmediata
        '✅ Reserva confirmada — $paciente',
        'Ficha $ticketNumber · $especialidad · $fecha $hora',
        details,
      );
      AppLogger.info(_tag, 'Booking confirmed notification sent — $ticketNumber');
    } catch (e, st) {
      AppLogger.error(_tag, 'showBookingConfirmed failed', e, st);
    }
  }

  // ── Recordatorios programados ───────────────────────────────────────────

  /// Programa 3 recordatorios: mañana del día, 2 horas antes, 30 min antes.
  /// Solo programa los que sean en el futuro.
  ///
  /// IDs usados:
  ///   ticketBase * 10 + 0  → mañana (8:00 AM del día de la cita)
  ///   ticketBase * 10 + 1  → 2 horas antes
  ///   ticketBase * 10 + 2  → 30 minutos antes
  static Future<void> scheduleAppointmentReminders({
    required String ticketNumber,
    required DateTime appointmentDateTime,
    required String especialidad,
    required String medico,
    required String paciente,
  }) async {
    try {
      await initialize();

      final appt = appointmentDateTime;
      final now = DateTime.now();

      final List<_Reminder> reminders = [
        _Reminder(
          id: _idFromTicket(ticketNumber, 0),
          time: DateTime(appt.year, appt.month, appt.day, 8, 0),
          title: '🏥 Cita médica hoy — $paciente',
          body: '$especialidad con $medico a las ${_hhmm(appt)}.',
        ),
        _Reminder(
          id: _idFromTicket(ticketNumber, 1),
          time: appt.subtract(const Duration(hours: 2)),
          title: '⏰ Tu cita es en 2 horas — $paciente',
          body: '$especialidad con $medico a las ${_hhmm(appt)}.',
        ),
        _Reminder(
          id: _idFromTicket(ticketNumber, 2),
          time: appt.subtract(const Duration(minutes: 30)),
          title: '🚨 Tu cita es en 30 min — $paciente',
          body: '¡Dirígete a $especialidad con $medico!',
        ),
      ];

      const androidDetails = AndroidNotificationDetails(
        'cossmil_reminder',
        'Recordatorios de citas COSSMIL',
        channelDescription: 'Recordatorios automáticos antes de tu cita médica',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      int scheduled = 0;
      for (final r in reminders) {
        if (r.time.isAfter(now)) {
          await _plugin.zonedSchedule(
            r.id,
            r.title,
            r.body,
            tz.TZDateTime.from(r.time, tz.local),
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          scheduled++;
          AppLogger.info(_tag, 'Scheduled reminder id=${r.id} at ${r.time}');
        } else {
          AppLogger.debug(_tag, 'Skipped past reminder at ${r.time}');
        }
      }
      AppLogger.info(_tag, '$scheduled/${reminders.length} reminders scheduled for $ticketNumber');
    } catch (e, st) {
      AppLogger.error(_tag, 'scheduleAppointmentReminders failed', e, st);
    }
  }

  /// Cancela los 3 recordatorios de una ficha.
  /// Llamar antes de reprogramar si la ficha cambia.
  static Future<void> cancelAppointmentReminders(String ticketNumber) async {
    try {
      await initialize();
      for (int i = 0; i < 3; i++) {
        await _plugin.cancel(_idFromTicket(ticketNumber, i));
      }
      AppLogger.info(_tag, 'Cancelled reminders for $ticketNumber');
    } catch (e, st) {
      AppLogger.error(_tag, 'cancelAppointmentReminders failed', e, st);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Deriva un notification ID único desde el número de ficha + sufijo.
  /// Ej: "K437" + sufijo 1 → hash(437) * 10 + 1
  static int _idFromTicket(String ticketNumber, int suffix) {
    final numeric = int.tryParse(ticketNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return (numeric % 99990) * 10 + suffix;
  }

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _Reminder {
  final int id;
  final DateTime time;
  final String title;
  final String body;
  const _Reminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
  });
}
