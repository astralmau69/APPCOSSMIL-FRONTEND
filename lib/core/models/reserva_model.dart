import '../extensions/string_extensions.dart';

/// Modelo de una cita/atención devuelta por el backend.
///
/// Mapea la respuesta de GET /api/programacion/historial-citas/{idper}/{page}/{size}.
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
  final String status; // 'Completado', 'Falta', 'Pendiente', 'Cancelado'
  final String? consultorio;
  final String? codigoReserva;

  // Campos del backend necesarios para descargar el PDF
  final int? gestion;
  final int? idins;
  final int? idsuc;
  final int? idtran;
  final int? dr;

  /// Estado de cancelación del backend: "0" = no cancelada, "1" = cancelada.
  final String estadoCancelacion;

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
    this.gestion,
    this.idins,
    this.idsuc,
    this.idtran,
    this.dr,
    this.estadoCancelacion = '0',
  });

  /// Parsea la respuesta real del endpoint historial-citas.
  ///
  /// Ejemplo de campo del backend:
  /// ```json
  /// {
  ///   "regional": "HMC-LPZ",
  ///   "idins": 1, "idsuc": 1, "idesp": 42,
  ///   "especialidad": "MEDICINA GENERAL",
  ///   "medico": "VILLAGOMEZ POSTIGO MARIANELA",
  ///   "codadm": "2026-1-1-468-10",
  ///   "fechaCita": "2026-01-13",
  ///   "dr": 10, "conf": "S",
  ///   "idtran": 165, "gestion": 2026, "estado": "N"
  /// }
  /// ```
  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    final gestion = json['gestion'] as int?;
    final idins = json['idins'] as int?;
    final idsuc = json['idsuc'] as int?;
    final int? idtran = (json['idtran'] ?? json['idtram']) as int?;
    final dr = json['dr'] as int?;
    
    // estadoCancelacion: "0" = no cancelada, "1" = cancelada
    final estadoCancelacionVal = (json['estadoCancelacion'] ?? json['cancelado'] ?? '0').toString();
    final bool isCancelado = estadoCancelacionVal == '1';

    return ReservaModel(
      id: (json['codadm'] ?? json['idreserva'] ?? json['id'] ?? '').toString(),
      patientName: (json['paciente'] as String? ??
          json['nombre_paciente'] as String? ??
          '').toDisplayCase,
      relationship: (json['parentesco'] as String? ?? 'Titular').toDisplayCase,
      specialty: (json['especialidad'] as String? ?? '').toDisplayCase,
      doctorName: (json['medico'] as String? ?? '').toDisplayCase,
      hospital: (json['regional'] as String? ??
          json['sucursal'] as String? ??
          '').toDisplayCase,
      city: (json['ciudad'] as String? ?? '').toDisplayCase,
      date: json['fechaCita'] as String? ??
          json['fecha'] as String? ??
          '',
      time: json['hora'] as String? ?? '',
      status: isCancelado
          ? 'Cancelado'
          : _parseStatus(json['estado'], json['fechaCita']?.toString() ?? json['fecha']?.toString() ?? ''),
      consultorio: json['consultorio'] as String?,
      codigoReserva: (json['codadm'] ?? json['codigo_reserva'] ?? json['ticket']).toString(),
      gestion: gestion,
      idins: idins,
      idsuc: idsuc,
      idtran: idtran,
      dr: dr,
      estadoCancelacion: estadoCancelacionVal,
    );
  }

  /// El backend usa "S" = atendido/completado, "N" = no atendido (falta o pendiente).
  /// Distinguimos "Pendiente" de "Falta" evaluando si la fecha ya pasó.
  static String _parseStatus(dynamic raw, String dateStr) {
    if (raw == null) return 'Pendiente';
    final s = raw.toString().toUpperCase().trim();
    if (s == '1') return 'Cancelado';
    if (s == '0') return 'Pendiente';
    if (s == 'S') return 'Completado';
    if (s == 'N') {
      try {
        if (dateStr.isNotEmpty) {
          final parts = dateStr.split(' ')[0].split('-');
          if (parts.length == 3) {
            final appDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            if (appDate.isBefore(today)) {
              return 'Falta';
            }
          }
        }
      } catch (_) {}
      return 'Pendiente';
    }
    // Fallback para otros formatos
    final lower = s.toLowerCase();
    if (lower == 'completado' || lower == 'atendido') return 'Completado';
    if (lower == 'falta' || lower == 'ausente') return 'Falta';
    if (lower == 'pendiente' || lower == 'reservado') return 'Pendiente';
    if (lower == 'cancelado') return 'Cancelado';
    return s.isNotEmpty ? s[0].toUpperCase() + s.substring(1).toLowerCase() : 'Pendiente';
  }

  /// Nombre para mostrar: si hay paciente lo usa, sino especialidad.
  String get displayName =>
      patientName.isNotEmpty ? patientName : specialty;

  /// Letra para avatar.
  String get avatarLetter =>
      specialty.isNotEmpty ? specialty[0] : patientName.isNotEmpty ? patientName[0] : '?';

  /// Si la atención pertenece al titular.
  bool get isTitular => relationship == 'Titular';

  /// Fecha formateada para mostrar (de yyyy-MM-dd a dd/MM/yyyy).
  String get formattedDate {
    if (date.isEmpty) return '';
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1].padLeft(2, '0')}/${parts[0]}';
      }
    } catch (_) {}
    return date;
  }

  /// Si puede descargar PDF (tiene los datos necesarios).
  bool get canDownloadPdf =>
      gestion != null && idins != null && idsuc != null && idtran != null && dr != null;

  /// Si se puede cancelar: estadoCancelacion == "0" y tiene los IDs necesarios.
  bool get canCancel =>
      estadoCancelacion == '0' && canDownloadPdf && status != 'Cancelado';

  ReservaModel copyWith({
    String? status,
    String? estadoCancelacion,
  }) {
    return ReservaModel(
      id: id,
      patientName: patientName,
      relationship: relationship,
      specialty: specialty,
      doctorName: doctorName,
      hospital: hospital,
      city: city,
      date: date,
      time: time,
      status: status ?? this.status,
      consultorio: consultorio,
      codigoReserva: codigoReserva,
      gestion: gestion,
      idins: idins,
      idsuc: idsuc,
      idtran: idtran,
      dr: dr,
      estadoCancelacion: estadoCancelacion ?? this.estadoCancelacion,
    );
  }
}
