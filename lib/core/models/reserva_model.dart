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

  /// ID del médico (para calificación). Viene como `idmed` en el historial.
  final String? idmed;

  /// ID de la especialidad (para calificación). Viene como `idesp` en el historial.
  final int? idesp;

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
    this.idmed,
    this.idesp,
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

    final rawHospital = (json['sucursal'] as String? ?? json['regional'] as String? ?? '').toDisplayCase;
    final normalizedHospital = _normalizeHospital(rawHospital);

    return ReservaModel(
      id: (json['codadm'] ?? json['idreserva'] ?? json['id'] ?? '').toString(),
      patientName: (json['paciente'] as String? ??
          json['nombre_paciente'] as String? ??
          '').toDisplayCase,
      relationship: (json['parentesco'] as String? ?? 'Titular').toDisplayCase,
      specialty: (json['especialidad'] as String? ?? '').toDisplayCase,
      doctorName: (json['medico'] as String? ?? '').toDisplayCase,
      hospital: normalizedHospital,
      city: (json['ciudad'] as String? ?? '').toDisplayCase,
      date: json['fechaCita'] as String? ??
          json['fecha'] as String? ??
          '',
      time: json['hora'] as String? ?? json['horaCita'] as String? ?? json['time'] as String? ?? '',
      status: isCancelado
          ? 'Cancelado'
          : _parseStatus(json['estado'], json['fechaCita']?.toString() ?? json['fecha']?.toString() ?? ''),
      consultorio: (json['consultorio'] ?? json['des_con'] ?? json['office'])?.toString(),
      codigoReserva: (json['codadm'] ?? json['codigo_reserva'] ?? json['ticket']).toString(),
      gestion: gestion,
      idins: idins,
      idsuc: idsuc,
      idtran: idtran,
      dr: dr,
      idmed: (json['idmed'] ?? json['idMed'] ?? json['id_medico'])?.toString(),
      idesp: json['idesp'] as int? ?? json['idEsp'] as int?,
      estadoCancelacion: estadoCancelacionVal,
    );
  }

  /// Expande abreviaciones de hospitales militares al nombre completo.
  static String _normalizeHospital(String name) {
    if (name.isEmpty) return '';
    final upper = name.toUpperCase();
    if (upper.contains('HMC')) return name.replaceAll(RegExp(r'HMC', caseSensitive: false), 'Hospital Militar Central');
    if (upper.contains('HMU')) return name.replaceAll(RegExp(r'HMU', caseSensitive: false), 'Hospital Militar Universitario');
    if (upper.contains('HMA')) return name.replaceAll(RegExp(r'HMA', caseSensitive: false), 'Hospital Militar de Área');
    if (upper.contains('HMB')) return name.replaceAll(RegExp(r'HMB', caseSensitive: false), 'Hospital Militar de Base');
    return name;
  }

  /// Mapeo directo de los códigos del backend:
  ///   N = Pendiente (cita reservada, aún no atendida)
  ///   P = Falta     (paciente no se presentó)
  ///   S = Atendido/Completado
  ///   1 = Cancelado (estadoCancelacion)
  ///   0 = Pendiente (estadoCancelacion activo)
  static String _parseStatus(dynamic raw, String dateStr) {
    if (raw == null) return 'Pendiente';
    final s = raw.toString().toUpperCase().trim();
    if (s == '1') return 'Cancelado';
    if (s == '0') return 'Pendiente';
    if (s == 'S') return 'Completado';
    if (s == 'N') return 'Pendiente';
    if (s == 'P') return 'Falta';
    // Fallback para strings descriptivos
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

  /// Si se puede cancelar: estadoCancelacion == "0", tiene los IDs necesarios,
  /// y faltan más de 2 horas para la cita.
  bool get canCancel {
    if (estadoCancelacion != '0') return false;
    if (!canDownloadPdf) return false;
    if (status == 'Cancelado') return false;
    return !isWithinTwoHoursOfAppointment;
  }

  /// True si la cita empieza en menos de 2 horas desde ahora.
  bool get isWithinTwoHoursOfAppointment {
    try {
      if (date.isEmpty) return false;
      final dateParts = date.split('-');
      if (dateParts.length < 3) return false;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      int hour = 0, minute = 0;
      if (time.isNotEmpty) {
        final tp = time.split(':');
        hour = int.tryParse(tp[0]) ?? 0;
        minute = int.tryParse(tp.length > 1 ? tp[1] : '0') ?? 0;
      }
      final dt = DateTime(year, month, day, hour, minute);
      return dt.difference(DateTime.now()).inMinutes < 120;
    } catch (_) {
      return false;
    }
  }

  /// Fecha de la cita como [DateTime] (solo año/mes/día, sin hora).
  /// Retorna null si la fecha no es parseable.
  DateTime? get appointmentDate {
    try {
      if (date.isEmpty) return null;
      final parts = date.split('-');
      if (parts.length < 3) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  /// True si la cita+hora de la cita ya pasó completamente.
  bool get isAppointmentPast {
    try {
      if (date.isEmpty) return false;
      final dateParts = date.split('-');
      if (dateParts.length < 3) return false;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);
      int hour = 23, minute = 59;
      if (time.isNotEmpty) {
        final tp = time.split(':');
        hour = int.tryParse(tp[0]) ?? 23;
        minute = int.tryParse(tp.length > 1 ? tp[1] : '59') ?? 59;
      }
      return DateTime.now().isAfter(DateTime(year, month, day, hour, minute));
    } catch (_) {
      return false;
    }
  }

  /// Hora en formato 24h con ceros (ej: 8:00 -> 08:00)
  String get formattedTime12h {
    if (time.isEmpty) return '';
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final h = parts[0].padLeft(2, '0');
        final m = parts[1].padLeft(2, '0');
        return '$h:$m';
      }
    } catch (_) {}
    return time;
  }

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
      idmed: idmed,
      idesp: idesp,
      estadoCancelacion: estadoCancelacion ?? this.estadoCancelacion,
    );
  }
}
