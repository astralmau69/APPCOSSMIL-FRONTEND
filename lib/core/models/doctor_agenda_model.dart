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
  final String foto; // bytes como string de enteros separados por coma
  final String consultorio;
  final String mtrmin;

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
  });

  factory DoctorAgendaModel.fromJson(Map<String, dynamic> json) {
    return DoctorAgendaModel(
      idagenda:    json['idagenda'] as String? ?? '',
      idmed:       (json['idmed'] ?? '').toString(),
      idcon:       json['idcon'] as int? ?? 0,
      medico:      (json['medico'] as String? ?? '').toDisplayCase,
      dia:         json['dia'] as String? ?? '',
      fecha:       json['fecha'] as String? ?? '',
      horaini:     json['horaini'] as String? ?? '',
      horafin:     json['horafin'] as String? ?? '',
      ase:         json['ase'] as int? ?? 0,
      oferta:      json['oferta'] as int? ?? 0,
      demanda:     json['demanda'] as int? ?? 0,
      ope:         json['ope'] as int? ?? 0,
      med:         json['med'] as int? ?? 0,
      adm:         json['adm'] as int? ?? 0,
      foto:        json['foto'] as String? ?? '',
      consultorio: (json['consultorio'] as String? ?? '').toDisplayCase,
      mtrmin:      json['mtrmin'] as String? ?? '',
    );
  }

  /// Convierte la foto (enteros con signo separados por coma) a bytes de imagen.
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
