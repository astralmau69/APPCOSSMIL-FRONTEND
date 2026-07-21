import 'package:shared_preferences/shared_preferences.dart';
import '../session/user_session.dart';
import 'notification_service.dart';
import 'programacion_service.dart';

/// Detecta citas que el backend marcó como «Completado» y dispara la
/// notificación de calificación — única fuente de esta lógica, compartida
/// entre [TabShellState] (revisión en primer plano/resumed) y
/// [BackgroundSyncService] (revisión periódica con la app cerrada).
class AppointmentStatusSync {
  AppointmentStatusSync._();

  /// Revisa las citas recientes del usuario actual y ofrece calificación
  /// para las que cambiaron a «Completado» hoy y aún no fueron ofrecidas.
  static Future<void> checkCompletedAppointments({
    ProgramacionService? service,
  }) async {
    if (!UserSession.isLoggedIn) return;
    try {
      final idperStr = UserSession.currentUser.id;
      if (idperStr.isEmpty) return;
      final idper = int.tryParse(idperStr);
      if (idper == null) return;

      final programacionService = service ?? ProgramacionService();
      final result = await programacionService.getHistorialCitas(
        idper,
        pagina: 1,
        cantidad: 10,
      );

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final prefs = await SharedPreferences.getInstance();

      for (final r in result.reservas) {
        if (r.status.toUpperCase() != 'COMPLETADO') continue;
        if (r.estadoCancelacion == '1') continue;

        // Solo citas de 2026 en adelante
        final apptDate = r.appointmentDate;
        if (apptDate == null || apptDate.year < 2026) continue;

        // Solo citas del día
        final isToday =
            !apptDate.isBefore(todayDate) &&
            apptDate.isBefore(todayDate.add(const Duration(days: 1)));
        if (!isToday) continue;

        // Verificar si ya fue calificada o la notificación ya fue ofrecida
        final ratedKey = 'rated_reserva_${r.idtran}_${r.dr}';
        final offeredKey = 'offered_reserva_${r.idtran}_${r.dr}';
        if (prefs.getBool(ratedKey) == true) continue;
        if (prefs.getBool(offeredKey) == true) continue;

        // Disparar notificación inmediata
        final ticket = r.codigoReserva ?? r.id;
        await NotificationService.showRatingReminder(
          ticketNumber: ticket,
          especialidad: r.specialty,
          medico: r.doctorName,
          paciente: r.patientName,
          idtran: r.idtran,
          dr: r.dr,
        );

        // Marcar como ofrecida para no repetirla en la próxima revisión
        await prefs.setBool(offeredKey, true);
      }
    } catch (_) {
      // Silencioso: no interrumpir el flujo normal si el API falla
    }
  }
}
