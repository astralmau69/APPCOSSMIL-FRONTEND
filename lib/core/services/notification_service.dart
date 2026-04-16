import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Color, Colors, Material, MediaQuery, Theme, Brightness;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../../app.dart';
import '../constants/app_colors.dart';
import '../services/programacion_service.dart';
import '../session/user_session.dart';
import '../utils/app_logger.dart';
import '../theme/sound_manager.dart';

/// Servicio de notificaciones locales para citas médicas.
///
/// Uso:
///   - [initialize] — llamar en main() antes de runApp
///   - [showBookingConfirmed] — notificación inmediata al confirmar
///   - [scheduleAppointmentReminders] — programa 5 recordatorios (2d, 1d, 3h, 30m, 15m)
///   - [cancelAppointmentReminders] — cancela los 5 por ticketId
///   - [rescheduleNotificationsForCurrentUser] — re-agenda al volver a iniciar sesión
class NotificationService {
  NotificationService._();

  static const _tag = 'NotificationService';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Almacenamiento para el mapeo idtran → ticketNumber.
  /// Necesario cuando el backend no devuelve idtran al confirmar reserva
  /// y se usa slotNumber como ticketNumber al programar notificaciones.
  static const _ticketStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
  );
  static const _ticketMapKey  = 'notif_ticket_map';
  /// Clave base para datos de citas persistidos por usuario.
  /// Formato real: 'notif_appts_<userId>'
  static const _apptDataKeyPrefix = 'notif_appts_';

  /// Callback registrado por TabShell para cambiar de pestaña desde una notificación.
  static void Function(int tab)? _onSwitchTab;

  /// TabShell llama esto en initState para permitir que las notificaciones
  /// de calificación abran la pestaña Mis Reservas automáticamente.
  static void registerTabSwitcher(void Function(int tab) fn) {
    _onSwitchTab = fn;
  }

  /// Cambia al tab indicado (usado desde cualquier parte de la app).
  static void switchTab(int tab) => _onSwitchTab?.call(tab);

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

    // No procesar si no hay sesión activa — el usuario está deslogueado.
    if (!UserSession.isLoggedIn) {
      AppLogger.debug(_tag, 'Notification tapped but no active session — ignoring');
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;

      // Verificar que la notificación pertenece al usuario actual.
      // Si el payload tiene un userId distinto al actual, ignorar.
      final notifUserId = data['userId'] as String?;
      if (notifUserId != null &&
          notifUserId.isNotEmpty &&
          notifUserId != UserSession.currentUser.id) {
        AppLogger.warn(_tag,
            'Notification userId=$notifUserId ≠ session userId=${UserSession.currentUser.id} — ignoring');
        return;
      }

      // Notificación de calificación → abrir Mis Reservas (tab 1)
      if (data['type'] == 'rating') {
        _onSwitchTab?.call(1);
        return;
      }
      _showAppointmentModal(data);
    } catch (e, st) {
      AppLogger.error(_tag, 'Failed to parse notification payload', e, st);
    }
  }

  static void _showAppointmentModal(Map<String, dynamic> data) {
    // Guardia defensiva: no mostrar modal si el usuario cerró sesión
    // entre el momento en que llegó la notificación y el tap.
    if (!UserSession.isLoggedIn) return;

    final ctx = CossmilApp.navigatorKey.currentContext;
    if (ctx == null) return;

    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    AudioPlayer? audioPlayer;

    // Play sound respecting in-app toggle; Android ringer check is async so fire-and-forget.
    if (SoundManager.isEnabled) {
      SoundManager.isDeviceSilentOrVibrate().then((silent) {
        if (!silent) {
          audioPlayer = AudioPlayer();
          audioPlayer!.play(AssetSource('vof/AUDIO 7. NOTIFICACION CITA MEDICA.mp3')).catchError((e) {
            AppLogger.error(_tag, 'Failed to play AUDIO 7', e);
          });
        }
      });
    }

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
      // ignore: use_build_context_synchronously
      Navigator.of(navCtx).pop(); // Quitar loader

      showCupertinoDialog(
        context: navCtx, // ignore: use_build_context_synchronously
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
      // ignore: use_build_context_synchronously
      Navigator.of(navCtx).pop(); // Quitar loader

      showCupertinoDialog(
        context: navCtx, // ignore: use_build_context_synchronously
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

  /// Programa 5 recordatorios vinculados al usuario y a la cita:
  ///   - 2 días antes a las 8:00 AM  (id sufijo 0)
  ///   - 1 día antes a las 8:00 AM   (id sufijo 1)
  ///   - 3 horas antes               (id sufijo 2)
  ///   - 30 minutos antes            (id sufijo 3)
  ///   - 15 minutos antes            (id sufijo 4)
  ///
  /// Solo programa los que sean en el futuro. Persiste los datos de la cita
  /// en [FlutterSecureStorage] para poder re-agendarlos tras un login/reinicio.
  ///
  /// [rescheduleOnly] = true → omite la persistencia (llamada interna al re-agendar).
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
    bool rescheduleOnly = false,
  }) async {
    try {
      await initialize();

      final appt = appointmentDateTime;
      final now  = tz.TZDateTime.now(tz.local);
      final fechaStr = fecha ?? '${appt.day.toString().padLeft(2,'0')}/${appt.month.toString().padLeft(2,'0')}/${appt.year}';
      final horaStr  = hora  ?? _hhmm(appt);
      final userId   = UserSession.currentUser.id;

      // ── Payload con datos de cancelación (para recordatorios lejanos) ────────
      final payload = jsonEncode({
        'userId': userId,
        'especialidad': especialidad,
        'medico': medico,
        'fecha': fechaStr,
        'hora': horaStr,
        'paciente': paciente,
        'ticket': ticketNumber,
        if (gestion != null) 'gestion': gestion,
        if (idins  != null) 'idins':  idins,
        if (idsuc  != null) 'idsuc':  idsuc,
        if (idtran != null) 'idtran': idtran,
        if (dr     != null) 'dr':     dr,
      });

      // ── Payload sin cancelación (para recordatorios muy cercanos) ────────────
      final payloadNoCancel = jsonEncode({
        'userId':       userId,
        'especialidad': especialidad,
        'medico':       medico,
        'fecha':        fechaStr,
        'hora':         horaStr,
        'paciente':     paciente,
        'ticket':       ticketNumber,
      });

      // ── Calcular tiempos base ────────────────────────────────────────────────
      final apptDay     = DateTime(appt.year, appt.month, appt.day);
      final twoDaysPrev = apptDay.subtract(const Duration(days: 2));
      final oneDayPrev  = apptDay.subtract(const Duration(days: 1));

      final List<_Reminder> reminders = [
        // 2 días antes — 8:00 AM
        _Reminder(
          id:    _idFromTicket(ticketNumber, 0),
          time:  DateTime(twoDaysPrev.year, twoDaysPrev.month, twoDaysPrev.day, 8, 0),
          title: 'Cita médica en 2 días — $paciente',
          body:  'El $fechaStr a las $horaStr tiene una cita de $especialidad con Dr. $medico. '
                 'Ficha $ticketNumber.',
        ),
        // 1 día antes — 8:00 AM
        _Reminder(
          id:    _idFromTicket(ticketNumber, 1),
          time:  DateTime(oneDayPrev.year, oneDayPrev.month, oneDayPrev.day, 8, 0),
          title: 'Cita médica mañana — $paciente',
          body:  'Mañana a las $horaStr tiene una cita de $especialidad con Dr. $medico. '
                 'Prepare su documentación. Ficha $ticketNumber.',
        ),
        // 3 horas antes
        _Reminder(
          id:    _idFromTicket(ticketNumber, 2),
          time:  appt.subtract(const Duration(hours: 3)),
          title: 'Cita médica en 3 horas — $paciente',
          body:  'A las $horaStr tiene una cita de $especialidad con Dr. $medico. '
                 'Puede cancelar desde la app si no podrá asistir.',
        ),
        // 30 minutos antes
        _Reminder(
          id:    _idFromTicket(ticketNumber, 3),
          time:  appt.subtract(const Duration(minutes: 30)),
          title: 'Cita médica en 30 minutos — $paciente',
          body:  'Su cita de $especialidad con Dr. $medico es a las $horaStr. '
                 'Diríjase al centro médico y ubique su consultorio. Ficha $ticketNumber.',
          payload: payloadNoCancel,
        ),
        // 15 minutos antes
        _Reminder(
          id:    _idFromTicket(ticketNumber, 4),
          time:  appt.subtract(const Duration(minutes: 15)),
          title: '¡Su cita comienza en 15 minutos! — $paciente',
          body:  'Especialidad: $especialidad · Dr. $medico · $horaStr. '
                 'Preséntese en el consultorio. Ficha $ticketNumber.',
          payload: payloadNoCancel,
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
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      int scheduled = 0;
      for (final r in reminders) {
        if (r.time.isAfter(now)) {
          await _plugin.zonedSchedule(
            r.id,
            r.title,
            r.body,
            tz.TZDateTime.from(r.time, tz.local),
            details,
            payload: r.payload ?? payload,
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
      AppLogger.info(_tag, '$scheduled/${reminders.length} reminders scheduled for ticket $ticketNumber');

      // ── Persistir para re-agendar tras login/reinicio ─────────────────────
      if (!rescheduleOnly) {
        await _saveAppointmentData(userId, ticketNumber, {
          'appointmentDateTime': appt.toIso8601String(),
          'especialidad': especialidad,
          'medico':       medico,
          'paciente':     paciente,
          'fecha':        fechaStr,
          'hora':         horaStr,
          if (gestion != null) 'gestion': gestion,
          if (idins   != null) 'idins':   idins,
          if (idsuc   != null) 'idsuc':   idsuc,
          if (idtran  != null) 'idtran':  idtran,
          if (dr      != null) 'dr':      dr,
        });
      }

      // ── Mapeo idtran → ticketNumber ────────────────────────────────────────
      if (idtran != null) {
        await _saveTicketMapping(idtran, ticketNumber);
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'scheduleAppointmentReminders failed', e, st);
    }
  }

  // ── Re-agendado al iniciar sesión ──────────────────────────────────────────

  /// Re-agenda todas las notificaciones pendientes del usuario actual.
  ///
  /// Llamar después de un login exitoso o restauración de sesión para que
  /// los recordatorios sobrevivan reinicios del dispositivo y actualizaciones
  /// de la app (Android borra las notificaciones pendientes en estos casos).
  ///
  /// Las citas ya pasadas se limpian automáticamente del almacenamiento.
  static Future<void> rescheduleNotificationsForCurrentUser() async {
    if (!UserSession.isLoggedIn) return;
    try {
      await initialize();
      final userId = UserSession.currentUser.id;
      if (userId.isEmpty) return;

      final raw = await _ticketStorage.read(key: '$_apptDataKeyPrefix$userId') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (map.isEmpty) return;

      final now = DateTime.now();
      final expired = <String>[];

      for (final entry in map.entries) {
        final ticket = entry.key;
        final data   = Map<String, dynamic>.from(entry.value as Map);
        try {
          final dtStr = data['appointmentDateTime'] as String?;
          if (dtStr == null) { expired.add(ticket); continue; }
          final apptDt = DateTime.parse(dtStr);

          // Cita terminada → eliminar del storage
          if (apptDt.isBefore(now.subtract(const Duration(hours: 1)))) {
            expired.add(ticket);
            continue;
          }

          await scheduleAppointmentReminders(
            ticketNumber:        ticket,
            appointmentDateTime: apptDt,
            especialidad:        data['especialidad']  as String? ?? '',
            medico:              data['medico']         as String? ?? '',
            paciente:            data['paciente']       as String? ?? '',
            fecha:               data['fecha']          as String?,
            hora:                data['hora']           as String?,
            gestion:             data['gestion']        as int?,
            idins:               data['idins']          as int?,
            idsuc:               data['idsuc']          as int?,
            idtran:              data['idtran']         as int?,
            dr:                  data['dr']             as int?,
            rescheduleOnly: true, // no re-persistir, ya están guardados
          );
        } catch (e) {
          AppLogger.error(_tag, 'reschedule failed for ticket=$ticket', e, null);
        }
      }

      // Limpiar citas expiradas
      if (expired.isNotEmpty) {
        for (final t in expired) map.remove(t);
        await _ticketStorage.write(
          key:   '$_apptDataKeyPrefix$userId',
          value: jsonEncode(map),
        );
        AppLogger.debug(_tag, 'Removed ${expired.length} expired appointment(s) from storage');
      }

      AppLogger.info(_tag, 'Re-scheduled notifications for ${map.length - expired.length} upcoming appointment(s)');
    } catch (e, st) {
      AppLogger.error(_tag, 'rescheduleNotificationsForCurrentUser failed', e, st);
    }
  }

  /// Cancela TODAS las notificaciones pendientes, limpia el mapeo y los datos
  /// de citas persistidos para el usuario actual (logout).
  static Future<void> cancelAllReminders() async {
    try {
      await initialize();
      await _plugin.cancelAll();
      await _ticketStorage.delete(key: _ticketMapKey);
      // Limpiar datos de citas del usuario actual
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        await _ticketStorage.delete(key: '$_apptDataKeyPrefix$userId');
      }
      AppLogger.info(_tag, 'All pending notifications and persisted data cleared (logout)');
    } catch (e, st) {
      AppLogger.error(_tag, 'cancelAllReminders failed', e, st);
    }
  }

  // ── Ticket mapping ─────────────────────────────────────────────────────────

  /// Guarda el mapeo [idtran] → [ticketNumber] cuando son distintos.
  /// Se necesita cuando el backend no devuelve idtran al confirmar y se usa
  /// slotNumber como ticketNumber para las notificaciones.
  static Future<void> _saveTicketMapping(int idtran, String ticketNumber) async {
    final key = idtran.toString();
    if (key == ticketNumber) return; // ya coinciden, no hace falta guardar
    try {
      final raw = await _ticketStorage.read(key: _ticketMapKey) ?? '{}';
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      map[key] = ticketNumber;
      await _ticketStorage.write(key: _ticketMapKey, value: jsonEncode(map));
      AppLogger.debug(_tag, 'Ticket mapping saved: $key → $ticketNumber');
    } catch (e) {
      AppLogger.error(_tag, '_saveTicketMapping failed', e, null);
    }
  }

  /// Devuelve el ticketNumber real usado al programar las notificaciones.
  /// Si no hay mapeo guardado, devuelve [idtran] sin cambios.
  static Future<String> _resolveTicketNum(String idtran) async {
    try {
      final raw = await _ticketStorage.read(key: _ticketMapKey) ?? '{}';
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      final resolved = map[idtran] ?? idtran;
      if (resolved != idtran) {
        AppLogger.debug(_tag, 'Ticket resolved: $idtran → $resolved');
      }
      return resolved;
    } catch (_) {
      return idtran;
    }
  }

  /// Elimina el mapeo de un idtran tras cancelar exitosamente.
  static Future<void> _removeTicketMapping(String idtran) async {
    try {
      final raw = await _ticketStorage.read(key: _ticketMapKey) ?? '{}';
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      if (map.remove(idtran) != null) {
        await _ticketStorage.write(key: _ticketMapKey, value: jsonEncode(map));
      }
    } catch (_) {}
  }

  // ── Cancelación ────────────────────────────────────────────────────────────

  /// Cancela todos los recordatorios y la confirmación de una ficha.
  /// Acepta el [idtran] de la reserva — resuelve automáticamente el ticketNumber
  /// real aunque durante la confirmación se haya usado slotNumber como fallback.
  ///
  /// Sufijos cancelados:
  ///   0 (2d antes), 1 (1d antes), 2 (3h antes), 3 (30min), 4 (15min),
  ///   9 (confirmación 5min).
  static Future<void> cancelAppointmentReminders(String idtran) async {
    try {
      await initialize();
      final ticketNumber = await _resolveTicketNum(idtran);
      for (final suffix in [0, 1, 2, 3, 4, 9]) {
        await _plugin.cancel(_idFromTicket(ticketNumber, suffix));
      }
      await _removeTicketMapping(idtran);
      // Eliminar datos persistidos de esta cita
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        await _removeAppointmentData(userId, ticketNumber);
      }
      AppLogger.info(_tag, 'Cancelled reminders for idtran=$idtran (ticket=$ticketNumber)');
    } catch (e, st) {
      AppLogger.error(_tag, 'cancelAppointmentReminders failed', e, st);
    }
  }

  // ── Persistencia de citas para re-agendado ────────────────────────────────

  static Future<void> _saveAppointmentData(
    String userId,
    String ticketNumber,
    Map<String, dynamic> data,
  ) async {
    if (userId.isEmpty) return;
    try {
      final key = '$_apptDataKeyPrefix$userId';
      final raw = await _ticketStorage.read(key: key) ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map[ticketNumber] = data;
      await _ticketStorage.write(key: key, value: jsonEncode(map));
      AppLogger.debug(_tag, 'Appointment data saved for ticket=$ticketNumber');
    } catch (e) {
      AppLogger.error(_tag, '_saveAppointmentData failed', e, null);
    }
  }

  static Future<void> _removeAppointmentData(
    String userId,
    String ticketNumber,
  ) async {
    if (userId.isEmpty) return;
    try {
      final key = '$_apptDataKeyPrefix$userId';
      final raw = await _ticketStorage.read(key: key) ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (map.remove(ticketNumber) != null) {
        await _ticketStorage.write(key: key, value: jsonEncode(map));
      }
    } catch (_) {}
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
  /// Payload propio. Si es null se usa el payload compartido del lote.
  final String? payload;
  const _Reminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    this.payload,
  });
}
