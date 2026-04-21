import 'dart:convert';
import 'dart:typed_data';
import '../extensions/string_extensions.dart';
import 'doctor_model.dart';

/// Representa un médico con su agenda del endpoint
/// medico-agenda-especialidad-cex/{idins}/{idsuc}/{fecha}/{idesp}.
class DoctorAgendaModel {
  final String idagenda;
  final String idmed;
  final int idcon;
  final String medico;
  final String dia;
  final String fecha;
  final String horaini;
  final String horafin;
  final int ase;     // fichas disponibles para modalidad ASE
  final int oferta;  // total de fichas ofertadas
  final int demanda;
  final int ope;
  final int med;
  final int adm;
  final String foto; // Base64 JPEG o bytes con signo separados por coma
  final String consultorio;
  final String mtrmin;
  final int disponibles; // New field from agenda-medico-movil
  final int iddia; // New field from agenda-medico-movil
  final bool estado; // Indicates if the day is available (true) or occupied (false)

  const DoctorAgendaModel({
    required this.idagenda,
    required this.idmed,
    required this.idcon,
    required this.medico,
    required this.dia,
    required this.fecha,
    required this.horaini,
    required this.horafin,
    required this.ase,
    required this.oferta,
    required this.demanda,
    required this.ope,
    required this.med,
    required this.adm,
    required this.foto,
    required this.consultorio,
    required this.mtrmin,
    this.disponibles = 0,
    this.iddia = 0,
    this.estado = false,
  });

  factory DoctorAgendaModel.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    String fullName = json['medico'] as String? ?? '';
    if (fullName.isEmpty) {
      final nom = json['nom'] as String? ?? '';
      final pat = json['pat'] as String? ?? '';
      final mat = json['mat'] as String? ?? '';
      fullName = '$nom $pat $mat'.trim();
    }

    return DoctorAgendaModel(
      idagenda:    json['idagenda'] as String? ?? '',
      idmed:       (json['idmed'] ?? '').toString(),
      idcon:       parseInt(json['idcon']),
      medico:      fullName.toDisplayCase,
      dia:         json['dia'] as String? ?? '',
      fecha:       json['fecha'] as String? ?? '',
      horaini:     json['horaini'] as String? ?? '',
      horafin:     json['horafin'] as String? ?? '',
      ase:         parseInt(json['ase']),
      oferta:      parseInt(json['oferta']),
      demanda:     parseInt(json['demanda']),
      ope:         parseInt(json['ope']),
      med:         parseInt(json['med']),
      adm:         parseInt(json['adm']),
      foto:        json['foto'] as String? ?? '',
      consultorio: (json['consultorio'] as String? ?? '').toDisplayCase,
      mtrmin:      json['mtrmin'] as String? ?? '',
      disponibles: parseInt(json['disponibles']),
      iddia:       parseInt(json['iddia']),
      estado:      json['estado'] == true || json['estado'] == 'true',
    );
  }

  /// Convierte la foto a bytes de imagen.
  /// Soporta dos formatos:
  ///  - Base64 estándar (endpoint medico-especialidad-consulta)
  ///  - Enteros con signo separados por coma (endpoint legacy)
  Uint8List? get photoBytes {
    if (foto.isEmpty) return null;
    // Detectar si es Base64: contiene '/', '+', '=' o solo alfanumérico sin comas
    if (!foto.contains(',')) {
      try {
        // Normalizar base64 (añadir padding si es necesario)
        String normalized = foto.replaceAll('\n', '').replaceAll('\r', '');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        return base64Decode(normalized);
      } catch (_) {
        return null;
      }
    }
    // Formato legacy: enteros con signo separados por coma
    try {
      final bytes = foto.split(',').map((s) {
        final v = int.parse(s.trim());
        return v < 0 ? v + 256 : v;
      }).toList();
      return Uint8List.fromList(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Rango horario formateado "08:00 – 14:00"
  String get rangoHorario {
    String fmt(String t) {
      final p = t.split(':');
      if (p.length >= 2) return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
      return t;
    }
    return '${fmt(horaini)} – ${fmt(horafin)}';
  }

  /// Compatibilidad con BookingState (DoctorModel).
  DoctorModel toDoctorModel() => DoctorModel(
    id: idmed,
    fullName: medico,
    office: consultorio,
    fecha: fecha,
    dia: dia,
    foto: foto,
  );
}
