import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/app_notification.dart';
import '../session/user_session.dart';
import '../services/notification_preferences.dart';
import '../utils/app_logger.dart';
import 'background_sync_service.dart';
import 'notification_initializer.dart';

/// Programa, persiste, re-agenda y cancela recordatorios de citas médicas.
///
/// Recordatorios por cita (5 en total):
///   - sufijo 0 → 2 días antes a las 8:00 AM   (exactAllowWhileIdle)
///   - sufijo 1 → 1 día antes a las 8:00 AM    (exactAllowWhileIdle)
///   - sufijo 2 → 3 horas antes                (exactAllowWhileIdle)
///   - sufijo 3 → 30 minutos antes             (alarmClock)
///   - sufijo 4 → 15 minutos antes             (alarmClock)
///   - sufijo 9 → confirmación 5 min tras reservar (alarmClock)
///
/// La notificación de calificación (sufijo 5) NO se programa por tiempo fijo.
/// Se dispara desde [showRatingReminder] cuando ReservasScreen detecta que
/// el backend cambió el estado de la cita a «Completado».
class NotificationScheduler {
  NotificationScheduler._();

  static const _tag = 'NotificationScheduler';

  static const _ticketStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
  );
  static const _ticketMapKey = 'notif_ticket_map';
  static const _apptDataKeyPrefix = 'notif_appts_';

  // ── Confirmación inmediata ──────────────────────────────────────────────────

  /// Programa una notificación de confirmación 5 minutos después de reservar.
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
      await NotificationInitializer.initialize();

      // Guard: preferencia de confirmaciones
      final userId = UserSession.currentUser.id;
      final canSend = await NotificationPreferences.getConfirmations(userId);
      if (!canSend) {
        AppLogger.debug(
          _tag,
          'Confirmación omitida por preferencia del usuario',
        );
        return;
      }

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
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // tz.TZDateTime.now(...).add(...) — NUNCA DateTime.now().add(...) envuelto
      // en TZDateTime.from(): .from() reinterpreta los campos (Y/M/D/H/M) del
      // DateTime recibido COMO SI ya fueran hora de America/La_Paz, ignorando
      // su offset real. Si el dispositivo tiene otro huso horario, "ahora + 5
      // min" quedaba desplazado por la diferencia entre ambos husos.
      final scheduledTime = tz.TZDateTime.now(
        tz.local,
      ).add(const Duration(minutes: 5));
      await _scheduleWithFallback(
        id: _idFromTicket(ticketNumber, 9),
        title: 'Cita Médica Confirmada — $especialidad',
        body:
            'Su cita médica con Dr. $medico fue registrada exitosamente para el $fecha a las $hora. Ficha $ticketNumber.',
        scheduledTime: scheduledTime,
        details: details,
        payload: payload,
        preferredMode: AndroidScheduleMode.alarmClock,
      );

      // Registrar en historial
      await NotificationPreferences.addToHistory(
        userId,
        AppNotification(
          id: 'booking_${ticketNumber}_${DateTime.now().millisecondsSinceEpoch}',
          type: AppNotificationType.booking,
          title: 'Cita Médica Confirmada — $especialidad',
          body: 'Dr. $medico · $fecha $hora · Ficha $ticketNumber · $paciente',
          createdAt: DateTime.now(),
          payload: {'ticket': ticketNumber, 'especialidad': especialidad},
        ),
      );

      AppLogger.info(
        _tag,
        'Booking confirmed notification scheduled in 5 min — $ticketNumber',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'showBookingConfirmed failed', e, st);
    }
  }

  // ── Recordatorios escalonados ───────────────────────────────────────────────

  /// Programa 6 recordatorios para la cita y persiste los datos para re-agendar.
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
      await NotificationInitializer.initialize();

      // Guard: preferencia de recordatorios
      final userId = UserSession.currentUser.id;
      final canSend = await NotificationPreferences.getReminders(userId);
      if (!canSend) {
        AppLogger.debug(
          _tag,
          'Recordatorios omitidos por preferencia del usuario',
        );
        return;
      }

      final appt = appointmentDateTime;
      final now = tz.TZDateTime.now(tz.local);
      final fechaStr =
          fecha ??
          '${appt.day.toString().padLeft(2, '0')}/${appt.month.toString().padLeft(2, '0')}/${appt.year}';
      final horaStr = hora ?? _hhmm(appt);

      // ── Payload con datos de cancelación (recordatorios lejanos) ────────────
      final payload = jsonEncode({
        'userId': userId,
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

      // ── Payload sin cancelación (recordatorios muy cercanos) ─────────────────
      final payloadNoCancel = jsonEncode({
        'userId': userId,
        'especialidad': especialidad,
        'medico': medico,
        'fecha': fechaStr,
        'hora': horaStr,
        'paciente': paciente,
        'ticket': ticketNumber,
      });

      final apptDay = DateTime(appt.year, appt.month, appt.day);
      final twoDaysPrev = apptDay.subtract(const Duration(days: 2));
      final oneDayPrev = apptDay.subtract(const Duration(days: 1));

      // Todas las horas se envuelven en tz.TZDateTime.from(...) EN LA
      // CONSTRUCCIÓN — no al momento de agendar — para que el filtro
      // "¿ya pasó?" de más abajo (r.time.isAfter(now)) compare instantes
      // realmente equivalentes. Antes `time` quedaba como DateTime "crudo"
      // (interpretado en el huso horario del dispositivo) y solo se
      // convertía a America/La_Paz justo antes de agendar: en un
      // dispositivo con otro huso horario, el filtro podía saltarse
      // recordatorios válidos o dejar pasar unos ya vencidos.
      final reminders = [
        // 2 días antes — 8:00 AM
        _Reminder(
          id: _idFromTicket(ticketNumber, 0),
          time: tz.TZDateTime.from(
            DateTime(
              twoDaysPrev.year,
              twoDaysPrev.month,
              twoDaysPrev.day,
              8,
              0,
            ),
            tz.local,
          ),
          title: 'Cita médica en 2 días — $paciente',
          body:
              'El $fechaStr a las $horaStr tiene una cita de $especialidad con Dr. $medico. '
              'Ficha $ticketNumber.',
          scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        ),
        // 1 día antes — 8:00 AM
        _Reminder(
          id: _idFromTicket(ticketNumber, 1),
          time: tz.TZDateTime.from(
            DateTime(oneDayPrev.year, oneDayPrev.month, oneDayPrev.day, 8, 0),
            tz.local,
          ),
          title: 'Cita médica mañana — $paciente',
          body:
              'Mañana a las $horaStr tiene una cita de $especialidad con Dr. $medico. '
              'Prepare su documentación. Ficha $ticketNumber.',
          scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        ),
        // 3 horas antes
        _Reminder(
          id: _idFromTicket(ticketNumber, 2),
          time: tz.TZDateTime.from(
            appt.subtract(const Duration(hours: 3)),
            tz.local,
          ),
          title: 'Cita médica en 3 horas — $paciente',
          body:
              'A las $horaStr tiene una cita de $especialidad con Dr. $medico. '
              'Puede cancelar desde la app si no podrá asistir.',
          scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        ),
        // 30 minutos antes — alarmClock
        _Reminder(
          id: _idFromTicket(ticketNumber, 3),
          time: tz.TZDateTime.from(
            appt.subtract(const Duration(minutes: 30)),
            tz.local,
          ),
          title: 'Cita médica en 30 minutos — $paciente',
          body:
              'Su cita de $especialidad con el Dr. $medico es a las $horaStr. '
              'Recuerde que debe presentarse en el consultorio 15 minutos antes de su hora de atención. Ficha $ticketNumber.',
          payload: payloadNoCancel,
          scheduleMode: AndroidScheduleMode.alarmClock,
        ),
        // 15 minutos antes — alarmClock
        _Reminder(
          id: _idFromTicket(ticketNumber, 4),
          time: tz.TZDateTime.from(
            appt.subtract(const Duration(minutes: 15)),
            tz.local,
          ),
          title: '¡Su cita comienza en 15 minutos! — $paciente',
          body:
              'Especialidad: $especialidad · Dr. $medico · $horaStr. '
              'Preséntese en el consultorio. Ficha $ticketNumber.',
          payload: payloadNoCancel,
          scheduleMode: AndroidScheduleMode.alarmClock,
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
          final ok = await _scheduleWithFallback(
            id: r.id,
            title: r.title,
            body: r.body,
            scheduledTime: r.time,
            details: details,
            payload: r.payload ?? payload,
            preferredMode: r.scheduleMode,
          );
          if (ok) {
            scheduled++;
            AppLogger.info(
              _tag,
              'Scheduled id=${r.id} mode=${r.scheduleMode.name} at ${r.time}',
            );
          }
        } else {
          AppLogger.debug(_tag, 'Skipped past reminder at ${r.time}');
        }
      }
      AppLogger.info(
        _tag,
        '$scheduled/${reminders.length} reminders scheduled for ticket $ticketNumber',
      );

      // Registrar en historial (solo primer schedule, no re-schedule)
      if (!rescheduleOnly) {
        final userId = UserSession.currentUser.id;
        await NotificationPreferences.addToHistory(
          userId,
          AppNotification(
            id: 'reminder_${ticketNumber}_${DateTime.now().millisecondsSinceEpoch}',
            type: AppNotificationType.reminder,
            title: 'Recordatorio agendado — $especialidad',
            body:
                'Cita con Dr. $medico · $paciente · $scheduled recordatorio(s) programado(s)',
            createdAt: DateTime.now(),
            payload: {'ticket': ticketNumber, 'especialidad': especialidad},
          ),
        );
      }

      // ── Persistir para re-agendar tras login/reinicio ──────────────────────
      if (!rescheduleOnly) {
        await _saveAppointmentData(userId, ticketNumber, {
          'appointmentDateTime': appt.toIso8601String(),
          'especialidad': especialidad,
          'medico': medico,
          'paciente': paciente,
          'fecha': fechaStr,
          'hora': horaStr,
          if (gestion != null) 'gestion': gestion,
          if (idins != null) 'idins': idins,
          if (idsuc != null) 'idsuc': idsuc,
          if (idtran != null) 'idtran': idtran,
          if (dr != null) 'dr': dr,
        });
      }

      if (idtran != null) {
        await _saveTicketMapping(idtran, ticketNumber);
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'scheduleAppointmentReminders failed', e, st);
    }
  }

  // ── Re-agendado al iniciar sesión ─────────────────────────────────────────

  /// Re-agenda todas las notificaciones pendientes del usuario actual.
  /// Llamar después de un login exitoso o restauración de sesión.
  static Future<void> rescheduleNotificationsForCurrentUser() async {
    if (!UserSession.isLoggedIn) return;
    try {
      await NotificationInitializer.initialize();
      final userId = UserSession.currentUser.id;
      if (userId.isEmpty) return;

      final raw =
          await _ticketStorage.read(key: '$_apptDataKeyPrefix$userId') ?? '{}';
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (map.isEmpty) return;

      final now = DateTime.now();
      final expired = <String>[];

      for (final entry in map.entries) {
        final ticket = entry.key;
        final data = Map<String, dynamic>.from(entry.value as Map);
        try {
          final dtStr = data['appointmentDateTime'] as String?;
          if (dtStr == null) {
            expired.add(ticket);
            continue;
          }
          final apptDt = DateTime.parse(dtStr);

          // Cita más de 3 horas pasada → eliminar del storage
          if (apptDt.isBefore(now.subtract(const Duration(hours: 3)))) {
            expired.add(ticket);
            continue;
          }

          await scheduleAppointmentReminders(
            ticketNumber: ticket,
            appointmentDateTime: apptDt,
            especialidad: data['especialidad'] as String? ?? '',
            medico: data['medico'] as String? ?? '',
            paciente: data['paciente'] as String? ?? '',
            fecha: data['fecha'] as String?,
            hora: data['hora'] as String?,
            gestion: data['gestion'] as int?,
            idins: data['idins'] as int?,
            idsuc: data['idsuc'] as int?,
            idtran: data['idtran'] as int?,
            dr: data['dr'] as int?,
            rescheduleOnly: true,
          );
        } catch (e) {
          AppLogger.error(
            _tag,
            'reschedule failed for ticket=$ticket',
            e,
            null,
          );
        }
      }

      if (expired.isNotEmpty) {
        for (final t in expired) {
          map.remove(t);
        }
        await _ticketStorage.write(
          key: '$_apptDataKeyPrefix$userId',
          value: jsonEncode(map),
        );
        AppLogger.debug(
          _tag,
          'Removed ${expired.length} expired appointment(s) from storage',
        );
      }

      AppLogger.info(
        _tag,
        'Re-scheduled notifications for ${map.length - expired.length} upcoming appointment(s)',
      );
    } catch (e, st) {
      AppLogger.error(
        _tag,
        'rescheduleNotificationsForCurrentUser failed',
        e,
        st,
      );
    }
  }

  // ── Notificación de calificación (evento real del backend) ──────────────────

  /// Dispara la notificación de calificación **inmediatamente** cuando
  /// ReservasScreen detecta que el backend cambió el estado a «Completado».
  ///
  /// Usa [show()] — no [zonedSchedule()] — porque el trigger ya ocurrió.
  /// Persiste en [SharedPreferences] (via DoctorRatingModal) que ya fue ofrecida,
  /// para no volver a mostrarla si el usuario refresca la lista.
  static Future<void> showRatingReminder({
    required String ticketNumber,
    required String especialidad,
    required String medico,
    required String paciente,
    int? idtran,
    int? dr,
  }) async {
    try {
      await NotificationInitializer.initialize();
      final userId = UserSession.currentUser.id;

      // Guard: preferencia de calificaciones
      final canSend = await NotificationPreferences.getRatings(userId);
      if (!canSend) {
        AppLogger.debug(
          _tag,
          'Rating reminder omitido por preferencia del usuario',
        );
        return;
      }

      final payload = jsonEncode({
        'userId': userId,
        'type': 'rating',
        'especialidad': especialidad,
        'medico': medico,
        'paciente': paciente,
        'ticket': ticketNumber,
        if (idtran != null) 'idtran': idtran,
        if (dr != null) 'dr': dr,
      });

      const androidDetails = AndroidNotificationDetails(
        'cossmil_rating_v1',
        'Calificación de cita COSSMIL',
        channelDescription: 'Solicitudes de calificación tras ser atendido',
        importance: Importance.high,
        priority: Priority.high,
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

      final notifId = _idFromTicket(ticketNumber, 5);
      await NotificationInitializer.plugin.show(
        notifId,
        '¿Cómo fue tu atención? — $paciente',
        'Califica tu cita de $especialidad con el Dr. $medico. '
            'Tu opinión nos ayuda a mejorar el servicio.',
        details,
        payload: payload,
      );

      // Registrar en historial
      await NotificationPreferences.addToHistory(
        userId,
        AppNotification(
          id: 'rating_${ticketNumber}_${DateTime.now().millisecondsSinceEpoch}',
          type: AppNotificationType.rating,
          title: '¿Cómo fue tu atención? — $paciente',
          body: 'Califica tu cita de $especialidad con el Dr. $medico.',
          createdAt: DateTime.now(),
          payload: {'ticket': ticketNumber, 'idtran': idtran, 'dr': dr},
        ),
      );

      AppLogger.info(
        _tag,
        'Rating reminder shown for ticket=$ticketNumber (estado=Completado)',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'showRatingReminder failed', e, st);
    }
  }

  // ── Cancelación ────────────────────────────────────────────────────────────

  /// Cancela todos los recordatorios (sufijos 0-5, 9) para un idtran.
  static Future<void> cancelAppointmentReminders(String idtran) async {
    try {
      await NotificationInitializer.initialize();
      final ticketNumber = await _resolveTicketNum(idtran);
      for (final suffix in [0, 1, 2, 3, 4, 5, 9]) {
        await NotificationInitializer.plugin.cancel(
          _idFromTicket(ticketNumber, suffix),
        );
      }
      await _removeTicketMapping(idtran);
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        await _removeAppointmentData(userId, ticketNumber);
      }
      AppLogger.info(
        _tag,
        'Cancelled reminders for idtran=$idtran (ticket=$ticketNumber)',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'cancelAppointmentReminders failed', e, st);
    }
  }

  /// Cancela TODAS las notificaciones y limpia el storage (logout).
  static Future<void> cancelAllReminders() async {
    try {
      await NotificationInitializer.initialize();
      await NotificationInitializer.plugin.cancelAll();
      await _ticketStorage.delete(key: _ticketMapKey);
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        await _ticketStorage.delete(key: '$_apptDataKeyPrefix$userId');
      }
      // Todos los call sites de cancelAllReminders() son logout real (token +
      // sesión limpiados) — cortar aquí la sincronización periódica evita
      // seguir consultando el backend por un usuario que ya cerró sesión.
      await BackgroundSyncService.cancel();
      AppLogger.info(
        _tag,
        'All pending notifications and persisted data cleared (logout)',
      );
    } catch (e, st) {
      AppLogger.error(_tag, 'cancelAllReminders failed', e, st);
    }
  }

  // ── Helpers privados ───────────────────────────────────────────────────────

  /// Programa con el modo preferido y hace fallback a inexacto si falla.
  static Future<bool> _scheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required NotificationDetails details,
    required String payload,
    required AndroidScheduleMode preferredMode,
  }) async {
    try {
      await NotificationInitializer.plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        payload: payload,
        androidScheduleMode: preferredMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (e) {
      AppLogger.warn(
        _tag,
        'Exact alarm (${preferredMode.name}) failed for id=$id — fallback a inexact. Error: $e',
      );
      try {
        await NotificationInitializer.plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTime,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return true;
      } catch (e2) {
        AppLogger.error(
          _tag,
          'Scheduling completamente fallido para id=$id',
          e2,
          null,
        );
        return false;
      }
    }
  }

  /// Deriva un notification ID único desde el número de ficha + sufijo.
  /// Usa hashCode del string completo para evitar colisiones entre formatos
  /// distintos (ej: "437" vs "K437" vs "1000437").
  static int _idFromTicket(String ticketNumber, int suffix) {
    final hash = ticketNumber.hashCode.abs() % 9999990;
    return hash * 10 + suffix;
  }

  static String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Persistencia ───────────────────────────────────────────────────────────

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

  static Future<void> _saveTicketMapping(
    int idtran,
    String ticketNumber,
  ) async {
    final key = idtran.toString();
    if (key == ticketNumber) return;
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

  static Future<void> _removeTicketMapping(String idtran) async {
    try {
      final raw = await _ticketStorage.read(key: _ticketMapKey) ?? '{}';
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      if (map.remove(idtran) != null) {
        await _ticketStorage.write(key: _ticketMapKey, value: jsonEncode(map));
      }
    } catch (_) {}
  }
}

// ── Modelo interno ─────────────────────────────────────────────────────────────

class _Reminder {
  final int id;
  final tz.TZDateTime time;
  final String title;
  final String body;

  /// Payload propio. Si es null se usa el payload compartido del lote.
  final String? payload;

  /// Modo de scheduling. Por defecto exactAllowWhileIdle.
  final AndroidScheduleMode scheduleMode;

  const _Reminder({
    required this.id,
    required this.time,
    required this.title,
    required this.body,
    this.payload,
    this.scheduleMode = AndroidScheduleMode.exactAllowWhileIdle,
  });
}
