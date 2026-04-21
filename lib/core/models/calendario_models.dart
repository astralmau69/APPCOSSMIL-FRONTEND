import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../extensions/string_extensions.dart';

// ─── MedicoSucModel ───────────────────────────────────────────────────────────
// Respuesta del endpoint POST /api/programacion/medsuc-buscar

class MedicoSucModel {
  final int idmed;
  final String nombre;
  final int idcon;
  final String consultorio;
  final String piso;
  final String foto;

  const MedicoSucModel({
    required this.idmed,
    required this.nombre,
    required this.idcon,
    required this.consultorio,
    required this.piso,
    required this.foto,
  });

  factory MedicoSucModel.fromJson(Map<String, dynamic> json) {
    int safeInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    String buildNombre() {
      final n = (json['nombre'] ?? json['medico'] ?? json['name'] ?? '').toString();
      if (n.isNotEmpty) return n;
      final nom = json['nom']?.toString() ?? '';
      final pat = json['pat']?.toString() ?? '';
      final mat = json['mat']?.toString() ?? '';
      return '$nom $pat $mat'.trim();
    }

    return MedicoSucModel(
      idmed: safeInt(json['idmed']),
      nombre: buildNombre().toDisplayCase,
      idcon: safeInt(json['idcon']),
      consultorio: ((json['consultorio'] ?? json['cons'] ?? '') as String? ?? '').toDisplayCase,
      piso: (json['piso'] ?? json['floor'] ?? '').toString(),
      foto: (json['foto'] ?? '').toString(),
    );
  }

  /// Determina el prefijo Dr./Dra. según el nombre (termina en 'A' → Dra.).
  String get prefix {
    final words = nombre.trim().split(' ');
    if (words.isEmpty) return 'Dr.';
    final last = words.last.toUpperCase();
    return (last.endsWith('A') || last.endsWith('AS')) ? 'Dra.' : 'Dr.';
  }

  String get displayName => '$prefix $nombre';

  /// Iniciales para el avatar fallback (máx. 2 letras).
  String get initials {
    final words = nombre.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  /// Decodifica la foto (enteros con signo separados por coma) a bytes.
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
}

// ─── HorarioMovilSlot ─────────────────────────────────────────────────────────
// Ítem individual del endpoint GET /api/programacion/horario-medico-movil/...

class HorarioMovilSlot {
  final String fecha;
  final String dia;
  final String horaini;
  final String horafin;
  final String consultorio;
  final String piso;
  final int cuposAse;

  const HorarioMovilSlot({
    required this.fecha,
    required this.dia,
    required this.horaini,
    required this.horafin,
    required this.consultorio,
    required this.piso,
    required this.cuposAse,
  });

  factory HorarioMovilSlot.fromJson(Map<String, dynamic> json) {
    String readStr(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    int safeInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    return HorarioMovilSlot(
      fecha: readStr(['fecha', 'date']),
      dia: readStr(['dia', 'day']).toDisplayCase,
      horaini: readStr(['horaini', 'hora_ini', 'horainicio', 'inicio']),
      horafin: readStr(['horafin', 'hora_fin', 'horafin', 'fin']),
      consultorio: readStr(['consultorio', 'cons', 'office']).toDisplayCase,
      piso: readStr(['piso', 'floor', 'nivel']),
      cuposAse: safeInt(json['ase'] ?? json['cupos'] ?? json['disponibles']),
    );
  }

  DateTime? get date => DateTime.tryParse(fecha);

  String get rangoHorario {
    String fmt(String t) {
      final p = t.split(':');
      if (p.length >= 2) return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
      return t;
    }
    return '${fmt(horaini)} – ${fmt(horafin)}';
  }
}

// ─── HorarioDia ───────────────────────────────────────────────────────────────
// Agrupación de slots por día para la UI

class HorarioDia {
  final String fecha;
  final String dia;
  final List<HorarioMovilSlot> slots;

  const HorarioDia({
    required this.fecha,
    required this.dia,
    required this.slots,
  });

  DateTime? get date => DateTime.tryParse(fecha);

  /// "Lunes, 13 de enero de 2025"
  String get diaLabel {
    final d = date;
    if (d == null) return dia;
    try {
      return DateFormat("EEEE, d 'de' MMMM 'de' y", 'es').format(d);
    } catch (_) {
      return dia;
    }
  }

  /// Consultorio y piso del primer slot (todos los slots del día comparten ubicación).
  String get consultorio => slots.isNotEmpty ? slots.first.consultorio : '';
  String get piso => slots.isNotEmpty ? slots.first.piso : '';
}
