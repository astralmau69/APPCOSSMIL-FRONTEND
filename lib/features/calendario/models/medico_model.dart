import 'dart:typed_data';

/// Médico retornado por la API de agenda por especialidad.
class MedicoCalendarioModel {
  final String idmed;
  final String medico;
  final String foto;
  final String consultorio;

  const MedicoCalendarioModel({
    required this.idmed,
    required this.medico,
    required this.foto,
    required this.consultorio,
  });

  factory MedicoCalendarioModel.fromJson(Map<String, dynamic> json) =>
      MedicoCalendarioModel(
        idmed:       (json['idmed'] ?? '').toString(),
        medico:      _toDisplayCase(json['medico'] as String? ?? ''),
        foto:        json['foto'] as String? ?? '',
        consultorio: _toDisplayCase(json['consultorio'] as String? ?? ''),
      );

  /// Iniciales para el avatar de respaldo (máx. 2 caracteres).
  String get initials {
    final parts = medico.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Convierte la cadena de bytes con signo a Uint8List para Image.memory.
  Uint8List? get photoBytes {
    if (foto.isEmpty) return null;
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

  static String _toDisplayCase(String s) {
    if (s.isEmpty) return s;
    return s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Turno/horario de un médico retornado por horario-medico-movil.
class MedicoHorarioModel {
  final String dia;
  final String horaini;
  final String horafin;
  final String turno;

  const MedicoHorarioModel({
    required this.dia,
    required this.horaini,
    required this.horafin,
    required this.turno,
  });

  factory MedicoHorarioModel.fromJson(Map<String, dynamic> json) =>
      MedicoHorarioModel(
        dia:     (json['dia'] as String? ?? '').toUpperCase(),
        horaini: json['horaini'] as String? ?? '',
        horafin: json['horafin'] as String? ?? '',
        turno:   _toTitleCase(json['turno'] as String? ?? ''),
      );

  /// "08:00 – 14:00"
  String get rango {
    String fmt(String t) {
      final p = t.split(':');
      return p.length >= 2
          ? '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}'
          : t;
    }
    return '${fmt(horaini)} – ${fmt(horafin)}';
  }

  static String _toTitleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

/// Resultado de búsqueda de médico por apellido/nombre (medsuc-buscar).
class MedicoBusquedaModel {
  final String idmed;
  final String pat;
  final String mat;
  final String nom;

  const MedicoBusquedaModel({
    required this.idmed,
    required this.pat,
    required this.mat,
    required this.nom,
  });

  factory MedicoBusquedaModel.fromJson(Map<String, dynamic> json) =>
      MedicoBusquedaModel(
        idmed: (json['idmed'] ?? '').toString(),
        pat:   _cap(json['pat'] as String? ?? ''),
        mat:   _cap(json['mat'] as String? ?? ''),
        nom:   _cap(json['nom'] as String? ?? ''),
      );

  String get nombreCompleto => '$pat $mat $nom'.trim();

  String get initials {
    final p = pat.trim();
    final n = nom.trim();
    if (p.isEmpty && n.isEmpty) return '?';
    return '${p.isNotEmpty ? p[0] : ''}${n.isNotEmpty ? n[0] : ''}'
        .toUpperCase();
  }

  static String _cap(String s) {
    if (s.isEmpty) return s;
    return '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';
  }
}
