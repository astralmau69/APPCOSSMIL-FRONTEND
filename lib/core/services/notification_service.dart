import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color, Theme, Brightness;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../app.dart';
import '../constants/app_colors.dart';
import '../utils/app_logger.dart';

/// Servicio de notificaciones locales para citas médicas.
///
/// Uso:
///   - [initialize] — llamar en main() antes de runApp
///   - [showBookingConfirmed] — notificación inmediata al confirmar
///   - [scheduleAppointmentReminders] — programa 4 recordatorios futuros
///   - [cancelAppointmentReminders] — cancela los 4 por ticketId
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
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Solicitar permiso en Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    AppLogger.info(_tag, 'Initialized — timezone: ${tz.local.name}');
  }

  // ── Tap handler ────────────────────────────────────────────────────────

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _showAppointmentModal(data);
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to parse notification payload', e, st);
    }
  }

  static void _showAppointmentModal(Map<String, dynamic> data) {
    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    AudioPlayer? audioPlayer;

    // Play AUDIO 7
    audioPlayer = AudioPlayer();
    audioPlayer.play(AssetSource('vof/AUDIO 7. NOTIFICACION CITA MEDICA.mp3')).catchError((e) {
      AppLogger.error(_tag, 'Failed to play AUDIO 7', e);
    });

    showCupertinoDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.bell_fill, color: AppColors.accentForTheme(isDark), size: 22),
              const SizedBox(width: 8),
              const Flexible(child: Text('Recordatorio de Cita')),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                _modalRow('Especialidad', data['especialidad'] ?? ''),
                const SizedBox(height: 6),
                _modalRow('Médico', data['medico'] ?? ''),
                const SizedBox(height: 6),
                _modalRow('Fecha', data['fecha'] ?? ''),
                const SizedBox(height: 6),
                _modalRow('Hora', data['hora'] ?? ''),
                const SizedBox(height: 6),
                _modalRow('Paciente', data['paciente'] ?? ''),
                if ((data['ticket'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _modalRow('Ficha', data['ticket'] ?? ''),
                ],
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Entendido'),
              onPressed: () {
                audioPlayer?.stop();
                audioPlayer?.dispose();
                Navigator.of(dialogCtx).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      // Ensure cleanup if dismissed by tapping outside
      audioPlayer?.stop();
      audioPlayer?.dispose();
    });
  }

  static Widget _modalRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
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

      final payload = jsonEncode({
        'especialidad': especialidad,
        'medico': medico,
        'fecha': fecha,
        'hora': hora,
        'paciente': paciente,
        'ticket': ticketNumber,
      });

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
        payload: payload,
      );
      AppLogger.info(_tag, 'Booking confirmed notification sent — $ticketNumber');
    } catch (e, st) {
      AppLogger.error(_tag, 'showBookingConfirmed failed', e, st);
    }
  }

  // ── Recordatorios programados ───────────────────────────────────────────

  /// Programa 4 recordatorios: mañana del día, 2 horas antes, 1 hora antes, 30 min antes.
  /// Solo programa los que sean en el futuro.
  ///
  /// IDs usados:
  ///   ticketBase * 10 + 0  → mañana (8:00 AM del día de la cita)
  ///   ticketBase * 10 + 1  → 2 horas antes
  ///   ticketBase * 10 + 2  → 1 hora antes
  ///   ticketBase * 10 + 3  → 30 minutos antes
  static Future<void> scheduleAppointmentReminders({
    required String ticketNumber,
    required DateTime appointmentDateTime,
    required String especialidad,
    required String medico,
    required String paciente,
    String? fecha,
    String? hora,
  }) async {
    try {
      await initialize();

      final appt = appointmentDateTime;
      final now = DateTime.now();
      final fechaStr = fecha ?? '${appt.day}/${appt.month}/${appt.year}';
      final horaStr = hora ?? _hhmm(appt);

      final payload = jsonEncode({
        'especialidad': especialidad,
        'medico': medico,
        'fecha': fechaStr,
        'hora': horaStr,
        'paciente': paciente,
        'ticket': ticketNumber,
      });

      final List<_Reminder> reminders = [
        _Reminder(
          id: _idFromTicket(ticketNumber, 0),
          time: DateTime(appt.year, appt.month, appt.day, 8, 0),
          title: '🏥 Cita médica hoy — $paciente',
          body: '$especialidad con $medico a las $horaStr.',
        ),
        _Reminder(
          id: _idFromTicket(ticketNumber, 1),
          time: appt.subtract(const Duration(hours: 2)),
          title: '⏰ Tu cita es en 2 horas — $paciente',
          body: '$especialidad con $medico a las $horaStr.',
        ),
        _Reminder(
          id: _idFromTicket(ticketNumber, 2),
          time: appt.subtract(const Duration(hours: 1)),
          title: '🔔 Tu cita es en 1 hora — $paciente',
          body: '$especialidad con $medico a las $horaStr. ¡Prepárate!',
        ),
        _Reminder(
          id: _idFromTicket(ticketNumber, 3),
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
            payload: payload,
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

  /// Cancela los 4 recordatorios de una ficha.
  /// Llamar antes de reprogramar si la ficha cambia.
  static Future<void> cancelAppointmentReminders(String ticketNumber) async {
    try {
      await initialize();
      for (int i = 0; i < 4; i++) {
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
