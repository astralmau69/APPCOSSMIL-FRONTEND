/// Modelo de una reserva/atención devuelta por el backend.
///
/// Mapea la respuesta de GET /api/programacion/reservas/{idper}/ASE.
/// Compatible con [AppointmentCard] para mostrar historial.
class ReservaModel {
  final String id;
  final String patientName;
  final String relationship;
  final String specialty;
  final String doctorName;
  final String hospital;
  final String city;
  final String date;
  final String time;
  final String status; // 'Completado', 'Falta', 'Pendiente'
  final String? consultorio;
  final String? codigoReserva;

  const ReservaModel({
    required this.id,
    required this.patientName,
    required this.relationship,
    required this.specialty,
    required this.doctorName,
    required this.hospital,
    required this.date,
    required this.time,
    required this.status,
    this.city = '',
    this.consultorio,
    this.codigoReserva,
  });

  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    return ReservaModel(
      id: (json['idreserva'] ?? json['id'] ?? '').toString(),
      patientName: json['paciente'] as String? ??
          json['nombre_paciente'] as String? ??
          json['patientName'] as String? ??
          '',
      relationship: json['parentesco'] as String? ??
          json['relationship'] as String? ??
          'Titular',
      specialty: json['especialidad'] as String? ??
          json['specialty'] as String? ??
          '',
      doctorName: json['medico'] as String? ??
          json['nombre_medico'] as String? ??
          json['doctorName'] as String? ??
          '',
      hospital: json['sucursal'] as String? ??
          json['establecimiento'] as String? ??
          json['hospital'] as String? ??
          '',
      city: json['ciudad'] as String? ?? json['city'] as String? ?? '',
      date: json['fecha'] as String? ?? json['date'] as String? ?? '',
      time: json['hora'] as String? ?? json['time'] as String? ?? '',
      status: _parseStatus(json['estado'] ?? json['status']),
      consultorio: json['consultorio'] as String? ??
          json['descripcion_consultorio'] as String?,
      codigoReserva: json['codigo_reserva'] as String? ??
          json['ticket'] as String? ??
          json['codigoReserva'] as String?,
    );
  }

  /// Normaliza el estado que viene del backend.
  static String _parseStatus(dynamic raw) {
    if (raw == null) return 'Pendiente';
    final s = raw.toString().toLowerCase().trim();
    if (s == 'completado' || s == 'atendido' || s == 'completo') {
      return 'Completado';
    }
    if (s == 'falta' || s == 'ausente' || s == 'no asistio') return 'Falta';
    if (s == 'pendiente' || s == 'reservado' || s == 'activo') {
      return 'Pendiente';
    }
    if (s == 'cancelado') return 'Cancelado';
    return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : 'Pendiente';
  }

  /// Letra para avatar.
  String get avatarLetter =>
      patientName.isNotEmpty ? patientName[0] : '?';

  /// Si la atención pertenece al titular.
  bool get isTitular => relationship == 'Titular';
}
