import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color, Colors, Material, MediaQuery, Theme, Brightness;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../app.dart';
import '../constants/app_colors.dart';
import '../services/programacion_service.dart';
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
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // Eliminar canales viejos (sin sonido custom) para que Android use los nuevos
    await androidPlugin?.deleteNotificationChannel('cossmil_booking');
    await androidPlugin?.deleteNotificationChannel('cossmil_reminder');

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

    audioPlayer = AudioPlayer();
    audioPlayer.play(AssetSource('vof/AUDIO 7. NOTIFICACION CITA MEDICA.mp3')).catchError((e) {
      AppLogger.error(_tag, 'Failed to play AUDIO 7', e);
    });

    final hasCancelData = data['gestion'] != null &&
        data['idins'] != null &&
        data['idsuc'] != null &&
        data['idtran'] != null &&
        data['dr'] != null;

    void cleanup() {
      audioPlayer?.stop();
      audioPlayer?.dispose();
    }

    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Recordatorio',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (dialogCtx, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(dialogCtx).size.width * 0.88,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con icono
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.bell_fill, size: 28, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Recordatorio de Cita Médica',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textPrimaryC(isDark),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tiene una cita médica programada próximamente',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                          color: AppColors.textSecondaryC(isDark),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                // Datos de la cita
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Column(
                    children: [
                      _modalInfoTile(CupertinoIcons.heart_circle, 'Especialidad', data['especialidad'] ?? '', isDark),
                      _modalInfoTile(CupertinoIcons.person, 'Médico', data['medico'] ?? '', isDark),
                      _modalInfoTile(CupertinoIcons.calendar, 'Fecha', data['fecha'] ?? '', isDark),
                      _modalInfoTile(CupertinoIcons.clock, 'Hora', data['hora'] ?? '', isDark),
                      _modalInfoTile(CupertinoIcons.person_2, 'Paciente', data['paciente'] ?? '', isDark),
                      if ((data['ticket'] ?? '').toString().isNotEmpty)
                        _modalInfoTile(CupertinoIcons.ticket, 'Ficha', data['ticket'] ?? '', isDark),
                    ],
                  ),
                ),
                // Botones
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      // Botón principal
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.primary,
                          onPressed: () {
                            cleanup();
                            Navigator.of(dialogCtx).pop();
                          },
                          child: const Text(
                            'Entendido',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                      // Botón cancelar cita
                      if (hasCancelData) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? CupertinoColors.destructiveRed.withValues(alpha: 0.15)
                                : CupertinoColors.destructiveRed.withValues(alpha: 0.08),
                            onPressed: () {
                              cleanup();
                              Navigator.of(dialogCtx).pop();
                              _confirmCancelFromNotification(data);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.xmark_circle_fill,
                                    size: 18, color: CupertinoColors.destructiveRed),
                                const SizedBox(width: 8),
                                Text(
                                  'Cancelar esta cita médica',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoColors.destructiveRed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => cleanup());
  }

  static Widget _modalInfoTile(IconData icon, String label, String value, bool isDark) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Confirma y ejecuta la cancelación de una cita desde la notificación.
  static void _confirmCancelFromNotification(Map<String, dynamic> data) {
    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    final especialidad = data['especialidad'] ?? '';
    final medico = data['medico'] ?? '';

    showCupertinoDialog(
      context: ctx,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Cancelar Cita'),
        content: Text(
          '¿Está seguro que desea cancelar su cita médica de $especialidad con el Dr. $medico?',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('No, mantener'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sí, cancelar'),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _executeCancelFromNotification(data);
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _executeCancelFromNotification(Map<String, dynamic> data) async {
    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    // Mostrar loader
    showCupertinoDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 15)),
    );

    try {
      final service = ProgramacionService();
      await service.cancelarCita(
        gestion: data['gestion'] as int,
        idins: data['idins'] as int,
        idsuc: data['idsuc'] as int,
        idtran: data['idtran'] as int,
        dr: data['dr'] as int,
      );

      // Cancelar notificaciones pendientes
      final ticket = data['ticket']?.toString() ?? '';
      if (ticket.isNotEmpty) {
        await cancelAppointmentReminders(ticket);
      }

      final navCtx = CossmilApp.navigatorKey.currentContext;
      if (navCtx == null) return;
      Navigator.of(navCtx).pop(); // Quitar loader

      showCupertinoDialog(
        context: navCtx,
        builder: (dCtx) => CupertinoAlertDialog(
          title: const Text('Cita Cancelada'),
          content: const Text('Su cita médica ha sido cancelada exitosamente.'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Entendido'),
              onPressed: () => Navigator.of(dCtx).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      final navCtx = CossmilApp.navigatorKey.currentContext;
      if (navCtx == null) return;
      Navigator.of(navCtx).pop(); // Quitar loader

      showCupertinoDialog(
        context: navCtx,
        builder: (dCtx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo cancelar la cita: $e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Aceptar'),
              onPressed: () => Navigator.of(dCtx).pop(),
            ),
          ],
        ),
      );
    }
  }

  // ── Notificación inmediata al confirmar reserva ─────────────────────────

  /// Programa una notificación de confirmación 5 minutos después de sacar la ficha.
  static Future<void> showBookingConfirmed({
    required String especialidad,
    required String medico,
    required String fecha,
    required String hora,
    required String paciente,
    required String ticketNumber,
    int? gestion,
    int? idins,
    int? idsuc,
    int? idtran,
    int? dr,
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
        if (gestion != null) 'gestion': gestion,
        if (idins != null) 'idins': idins,
        if (idsuc != null) 'idsuc': idsuc,
        if (idtran != null) 'idtran': idtran,
        if (dr != null) 'dr': dr,
      });

      final androidDetails = AndroidNotificationDetails(
        'cossmil_booking_v2',
        'Reservas COSSMIL',
        channelDescription: 'Confirmaciones de citas médicas',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF0C4A6E),
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notificacion_cita'),
        styleInformation: BigTextStyleInformation(
          'Especialidad: $especialidad\nMédico: Dr. $medico\nFecha: $fecha — Hora: $hora\nPaciente: $paciente',
          contentTitle: 'Cita Médica Confirmada - Ficha $ticketNumber',
          summaryText: 'COSSMIL',
        ),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notificacion_cita.mp3',
      );
      final details =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Programar 5 minutos después de la confirmación
      final scheduledTime = DateTime.now().add(const Duration(minutes: 5));
      await _plugin.zonedSchedule(
        _idFromTicket(ticketNumber, 9),
        'Cita Médica Confirmada — $especialidad',
        'Su cita médica con Dr. $medico fue registrada exitosamente para el $fecha a las $hora. Ficha $ticketNumber.',
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      AppLogger.info(_tag, 'Booking confirmed notification scheduled in 5 min — $ticketNumber');
    } catch (e, st) {
      AppLogger.error(_tag, 'showBookingConfirmed failed', e, st);
    }
  }

  // ── Recordatorios programados ───────────────────────────────────────────

  /// Programa 2 recordatorios basados en la hora de la cita médica:
  ///   - 2 horas antes de la cita médica
  ///   - 30 minutos antes de la cita médica
  /// Solo programa los que sean en el futuro.
  ///
  /// IDs usados:
  ///   ticketBase * 10 + 1  → 2 horas antes
  ///   ticketBase * 10 + 3  → 30 minutos antes
  static Future<void> scheduleAppointmentReminders({
    required String ticketNumber,
    required DateTime appointmentDateTime,
    required String especialidad,
    required String medico,
    required String paciente,
    String? fecha,
    String? hora,
    int? gestion,
    int? idins,
    int? idsuc,
    int? idtran,
    int? dr,
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
        if (gestion != null) 'gestion': gestion,
        if (idins != null) 'idins': idins,
        if (idsuc != null) 'idsuc': idsuc,
        if (idtran != null) 'idtran': idtran,
        if (dr != null) 'dr': dr,
      });

      final List<_Reminder> reminders = [
        _Reminder(
          id: _idFromTicket(ticketNumber, 1),
          time: appt.subtract(const Duration(hours: 2)),
          title: 'Cita Médica en 2 horas — $paciente',
          body: 'Tiene una cita médica de $especialidad con Dr. $medico programada a las $horaStr. '
              'Recuerde prepararse con anticipación. Puede cancelar desde la app si no podrá asistir.',
        ),
        _Reminder(
          id: _idFromTicket(ticketNumber, 3),
          time: appt.subtract(const Duration(minutes: 30)),
          title: 'Cita Médica en 30 minutos — $paciente',
          body: 'Su cita médica de $especialidad con Dr. $medico es a las $horaStr. '
              'Diríjase al centro médico y ubique su consultorio. Ficha $ticketNumber.',
        ),
      ];

      const androidDetails = AndroidNotificationDetails(
        'cossmil_reminder_v2',
        'Recordatorios de citas COSSMIL',
        channelDescription: 'Recordatorios automáticos antes de tu cita médica',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notificacion_cita'),
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: 'notificacion_cita.mp3',
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

  /// Cancela todos los recordatorios y la confirmación de una ficha.
  static Future<void> cancelAppointmentReminders(String ticketNumber) async {
    try {
      await initialize();
      // IDs: 1 (2h antes), 3 (30min antes), 9 (confirmación 5min)
      for (final suffix in [1, 3, 9]) {
        await _plugin.cancel(_idFromTicket(ticketNumber, suffix));
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
