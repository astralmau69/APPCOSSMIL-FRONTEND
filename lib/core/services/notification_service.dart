// Fachada pública del sistema de notificaciones de COSSMIL.
//
// Todos los call sites existentes usan esta clase sin cambios.
// La lógica está dividida en tres módulos especializados:
//
//   - NotificationInitializer  — init, canales, permisos, batería
//   - NotificationScheduler    — scheduling, persistencia, re-agendado
//   - NotificationUiHandler    — modal in-app, tap handler, callbacks UI
//
// Responsabilidad de esta clase:
//   1. Re-exportar la API pública de los tres módulos.
//   2. Registrar el callback de cancelación de recordatorios en NotificationUiHandler
//      (evita dependencia circular entre ui y scheduler).

import 'notification_initializer.dart';
import 'notification_scheduler.dart';
import 'notification_ui.dart';

class NotificationService {
  NotificationService._();

  // ── Inicialización ─────────────────────────────────────────────────────────

  /// Inicializa el plugin, canales y timezone.
  /// Llama una vez en main() antes de runApp().
  static Future<void> initialize() async {
    // Registrar callback de cancelación de recordatorios en el handler de UI
    // para evitar que notification_ui importe notification_scheduler.
    NotificationUiHandler.registerCancelRemindersHandler(
      NotificationScheduler.cancelAppointmentReminders,
    );
    await NotificationInitializer.initialize();
  }

  // ── Permisos ───────────────────────────────────────────────────────────────

  static Future<bool> requestPermissions() =>
      NotificationInitializer.requestPermissions();

  static Future<bool> areNotificationsEnabled() =>
      NotificationInitializer.areNotificationsEnabled();

  static Future<void> requestBatteryOptimizationExemption() =>
      NotificationInitializer.requestBatteryOptimizationExemption();

  /// Despacha la notificación que abrió la app en frío (app cerrada por
  /// completo). Ver [NotificationInitializer.consumeAppLaunchNotification].
  static Future<void> consumeAppLaunchNotification() =>
      NotificationInitializer.consumeAppLaunchNotification();

  // ── Navegación / callbacks ─────────────────────────────────────────────────

  /// Registrar por TabShell para cambiar de tab desde una notificación.
  static void registerTabSwitcher(void Function(int tab) fn) =>
      NotificationUiHandler.registerTabSwitcher(fn);

  /// Registrar por TabShell para ejecutar la cancelación HTTP de una cita.
  /// Recibe el payload decodificado (gestion, idins, idsuc, idtran, dr).
  static void registerCancelCitaHandler(
    Future<void> Function(Map<String, dynamic> data) fn,
  ) => NotificationUiHandler.registerCancelCitaHandler(fn);

  static void switchTab(int tab) => NotificationUiHandler.switchTab(tab);

  // ── Scheduling ─────────────────────────────────────────────────────────────

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
  }) => NotificationScheduler.showBookingConfirmed(
    especialidad: especialidad,
    medico: medico,
    fecha: fecha,
    hora: hora,
    paciente: paciente,
    ticketNumber: ticketNumber,
    gestion: gestion,
    idins: idins,
    idsuc: idsuc,
    idtran: idtran,
    dr: dr,
  );

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
  }) => NotificationScheduler.scheduleAppointmentReminders(
    ticketNumber: ticketNumber,
    appointmentDateTime: appointmentDateTime,
    especialidad: especialidad,
    medico: medico,
    paciente: paciente,
    fecha: fecha,
    hora: hora,
    gestion: gestion,
    idins: idins,
    idsuc: idsuc,
    idtran: idtran,
    dr: dr,
    rescheduleOnly: rescheduleOnly,
  );

  static Future<void> cancelAppointmentReminders(String idtran) =>
      NotificationScheduler.cancelAppointmentReminders(idtran);

  static Future<void> cancelAllReminders() =>
      NotificationScheduler.cancelAllReminders();

  static Future<void> rescheduleNotificationsForCurrentUser() =>
      NotificationScheduler.rescheduleNotificationsForCurrentUser();

  /// Dispara la notificación de calificación inmediatamente.
  /// Llamar desde ReservasScreen cuando detecta que el backend marcó
  /// la cita como «Completado» por primera vez en la sesión.
  static Future<void> showRatingReminder({
    required String ticketNumber,
    required String especialidad,
    required String medico,
    required String paciente,
    int? idtran,
    int? dr,
  }) => NotificationScheduler.showRatingReminder(
    ticketNumber: ticketNumber,
    especialidad: especialidad,
    medico: medico,
    paciente: paciente,
    idtran: idtran,
    dr: dr,
  );
}
