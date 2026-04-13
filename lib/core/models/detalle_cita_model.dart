import '../extensions/string_extensions.dart';

/// Modelo del detalle de una cita médica.
///
/// Mapea la respuesta de GET /api/programacion/detalle-cita-medica/{gestion}/{idins}/{idsuc}/{idtran}/{dr}.
class DetalleCitaModel {
  final int gestion;
  final int idins;
  final int idsuc;
  final int idtran;
  final int dr;
  final String matricula;
  final String especialidad;
  final String consultorio;
  final String abrcons;
  final String fechaCita;
  final String horaCita;
  final int numero;
  final String medico;
  final String obs;
  final String sucursal;
  final String codadm;
  final String paciente;
  final String? tipoConsulta;
  final String estadoConfirmacion;
  final String estadoAtencion;
  final String fechaCreacion;
  final String? fotoMedico;

  const DetalleCitaModel({
    required this.gestion,
    required this.idins,
    required this.idsuc,
    required this.idtran,
    required this.dr,
    required this.matricula,
    required this.especialidad,
    required this.consultorio,
    required this.abrcons,
    required this.fechaCita,
    required this.horaCita,
    required this.numero,
    required this.medico,
    required this.obs,
    required this.sucursal,
    required this.codadm,
    required this.paciente,
    this.tipoConsulta,
    required this.estadoConfirmacion,
    required this.estadoAtencion,
    required this.fechaCreacion,
    this.fotoMedico,
  });

  factory DetalleCitaModel.fromJson(Map<String, dynamic> json) {
    final rawSucursal = (json['sucursal'] as String? ?? '').toDisplayCase;
    return DetalleCitaModel(
      gestion: json['gestion'] as int? ?? 0,
      idins: json['idins'] as int? ?? 0,
      idsuc: json['idsuc'] as int? ?? 0,
      idtran: (json['idtran'] ?? json['idtram']) as int? ?? 0,
      dr: json['dr'] as int? ?? 0,
      matricula: (json['matricula'] as String? ?? '').trim(),
      especialidad: (json['especialidad'] as String? ?? '').toDisplayCase,
      consultorio: (json['consultorio'] as String? ?? '').toDisplayCase,
      abrcons: (json['abrcons'] as String? ?? '').toDisplayCase,
      fechaCita: json['fechaCita'] as String? ?? '',
      horaCita: json['horaCita'] as String? ?? '',
      numero: json['numero'] as int? ?? 0,
      medico: (json['medico'] as String? ?? '').toDisplayCase,
      obs: json['obs'] as String? ?? '',
      sucursal: _normalizeHospital(rawSucursal),
      codadm: json['codadm'] as String? ?? '',
      paciente: (json['paciente'] as String? ?? '').toDisplayCase,
      tipoConsulta: json['tipoConsulta'] as String?,
      estadoConfirmacion: json['estadoConfirmacion'] as String? ?? '',
      estadoAtencion: json['estadoAtencion'] as String? ?? '',
      fechaCreacion: json['fechaCreacion'] as String? ?? '',
      fotoMedico: json['fotoMedico'] as String? ?? json['foto'] as String? ?? json['base64'] as String?,
    );
  }

  static String _normalizeHospital(String name) {
    if (name.isEmpty) return '';
    final upper = name.toUpperCase();
    if (upper.contains('HMC')) return name.replaceAll(RegExp(r'HMC', caseSensitive: false), 'Hospital Militar Central');
    if (upper.contains('HMU')) return name.replaceAll(RegExp(r'HMU', caseSensitive: false), 'Hospital Militar Universitario');
    if (upper.contains('HMA')) return name.replaceAll(RegExp(r'HMA', caseSensitive: false), 'Hospital Militar de Área');
    if (upper.contains('HMB')) return name.replaceAll(RegExp(r'HMB', caseSensitive: false), 'Hospital Militar de Base');
    return name;
  }

  /// Fecha formateada dd/MM/yyyy.
  String get formattedDate {
    if (fechaCita.isEmpty) return '';
    try {
      final parts = fechaCita.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1].padLeft(2, '0')}/${parts[0]}';
      }
    } catch (_) {}
    return fechaCita;
  }

  /// Fecha de creación formateada.
  String get formattedCreation {
    if (fechaCreacion.isEmpty) return '';
    try {
      final dt = DateTime.parse(fechaCreacion);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return fechaCreacion;
  }

  /// Hora en formato 24h con ceros (ej: 8:00 -> 08:00)
  String get formattedTime12h {
    if (horaCita.isEmpty) return '';
    try {
      final parts = horaCita.split(':');
      if (parts.length >= 2) {
        final h = parts[0].padLeft(2, '0');
        final m = parts[1].padLeft(2, '0');
        return '$h:$m';
      }
    } catch (_) {}
    return horaCita;
  }
}
