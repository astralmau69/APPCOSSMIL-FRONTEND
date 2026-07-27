/// Datos mock del historial de atenciones médicas.
/// Regla de negocio: solo se muestra historial (no próximas).
/// Las fichas se sacan para el día siguiente, una por persona por día.
/// Estados posibles: 'Completado', 'Falta'.
/// Preparado para ser reemplazado por servicio REST.
class MockAppointmentItem {
  final String id;
  final String patientName;
  final String patientInitial;
  final String relationship; // 'Titular', 'Esposa', 'Hijo', 'Hija'
  final String specialty;
  final String doctorName;
  final String hospital;
  final String city;
  final String date;
  final String time;
  final String status; // 'Completado', 'Falta'
  final String? consultorio;
  final String? codigoReserva;

  const MockAppointmentItem({
    required this.id,
    required this.patientName,
    required this.relationship,
    required this.specialty,
    required this.doctorName,
    required this.hospital,
    required this.date,
    required this.time,
    required this.status,
    this.patientInitial = '',
    this.city = '',
    this.consultorio,
    this.codigoReserva,
  });

  /// Letra para avatar.
  String get avatarLetter => patientInitial.isNotEmpty
      ? patientInitial
      : (patientName.isNotEmpty ? patientName[0] : '?');

  /// Si la atención pertence al titular.
  bool get isTitular => relationship == 'Titular';
}

class MockAppointmentsData {
  /// Historial de atenciones (solo Completado / Falta).
  static const List<MockAppointmentItem> history = [
    // ── Completadas ─────────────────────────────────────────────────────────
    MockAppointmentItem(
      id: 'h1',
      patientName: 'Javier Arispe Mendez',
      patientInitial: 'J',
      relationship: 'Titular',
      specialty: 'Medicina General',
      doctorName: 'Dr. Roberto Guzmán',
      hospital: 'Hospital Militar Central',
      city: 'La Paz',
      date: '17 Mar 2026',
      time: '09:00',
      status: 'Completado',
      consultorio: 'Consultorio 204 - Planta Baja',
      codigoReserva: 'RES-20260317-4821',
    ),
    MockAppointmentItem(
      id: 'h2',
      patientName: 'Carolina Gomez',
      patientInitial: 'C',
      relationship: 'Esposa',
      specialty: 'Ginecología',
      doctorName: 'Dra. Lucía Fernández',
      hospital: 'Hospital Militar Central',
      city: 'La Paz',
      date: '14 Mar 2026',
      time: '08:30',
      status: 'Completado',
      consultorio: 'Consultorio 105 - 1er Piso',
      codigoReserva: 'RES-20260314-3456',
    ),
    MockAppointmentItem(
      id: 'h3',
      patientName: 'Javier Arispe Mendez',
      patientInitial: 'J',
      relationship: 'Titular',
      specialty: 'Odontología',
      doctorName: 'Dra. Paola Suarez',
      hospital: 'COSSMIL Cochabamba',
      city: 'Cochabamba',
      date: '10 Mar 2026',
      time: '11:00',
      status: 'Completado',
      consultorio: 'Consultorio 08',
      codigoReserva: 'RES-20260310-9012',
    ),
    MockAppointmentItem(
      id: 'h4',
      patientName: 'Valeria Arispe Gomez',
      patientInitial: 'V',
      relationship: 'Hija',
      specialty: 'Pediatría',
      doctorName: 'Dr. Carlos Montaño',
      hospital: 'Hospital Militar Central',
      city: 'La Paz',
      date: '07 Mar 2026',
      time: '14:15',
      status: 'Completado',
      consultorio: 'Consultorio 312 - 3er Piso',
      codigoReserva: 'RES-20260307-5567',
    ),
    // ── Falta ───────────────────────────────────────────────────────────────
    MockAppointmentItem(
      id: 'h5',
      patientName: 'Mateo Arispe Gomez',
      patientInitial: 'M',
      relationship: 'Hijo',
      specialty: 'Cardiología',
      doctorName: 'Dr. Andrés Villarreal',
      hospital: 'Hospital Militar Central',
      city: 'La Paz',
      date: '05 Mar 2026',
      time: '09:40',
      status: 'Falta',
      consultorio: 'Consultorio 401 - 4to Piso',
      codigoReserva: 'RES-20260305-2389',
    ),
  ];

  /// Conteo de atenciones completadas.
  static int get completedCount =>
      history.where((a) => a.status == 'Completado').length;

  /// Conteo de faltas.
  static int get missedCount =>
      history.where((a) => a.status == 'Falta').length;
}
