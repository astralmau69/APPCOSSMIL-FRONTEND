import 'doctor_model.dart';
import 'time_slot_model.dart';

/// Respuesta del endpoint medico-asignado.
/// Contiene datos del médico, consultorio y horas disponibles.
class MedicoAsignadoModel {
  final String idagenda;
  final int idesp;
  final String idmed;
  final String medico;
  final int oferta;
  final int demanda;
  final int nroini;
  final bool estado;
  final int idcon;
  final String descripcionConsultorio;
  final String dia;
  final String fecha;
  final String idcontrol;
  final List<HoraDisponibleModel> horas;

  const MedicoAsignadoModel({
    required this.idagenda,
    required this.idesp,
    required this.idmed,
    required this.medico,
    required this.oferta,
    required this.demanda,
    required this.nroini,
    required this.estado,
    required this.idcon,
    required this.descripcionConsultorio,
    required this.dia,
    required this.fecha,
    required this.idcontrol,
    required this.horas,
  });

  factory MedicoAsignadoModel.fromJson(Map<String, dynamic> json) {
    final horasList = (json['horas'] as List<dynamic>? ?? [])
        .map((e) => HoraDisponibleModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return MedicoAsignadoModel(
      idagenda: json['idagenda'] as String? ?? '',
      idesp: json['idesp'] as int? ?? 0,
      idmed: (json['idmed'] ?? '').toString(),
      medico: json['medico'] as String? ?? '',
      oferta: json['oferta'] as int? ?? 0,
      demanda: json['demanda'] as int? ?? 0,
      nroini: json['nroini'] as int? ?? 0,
      estado: json['estado'] as bool? ?? false,
      idcon: json['idcon'] as int? ?? 0,
      idcontrol: json['idcontrol'] as String? ?? '',
      descripcionConsultorio: json['descripcion'] as String? ?? '',
      dia: json['dia'] as String? ?? '',
      fecha: json['fecha'] as String? ?? '',
      horas: horasList,
    );
  }

  /// Convierte a DoctorModel para compatibilidad con BookingState.
  DoctorModel toDoctorModel() => DoctorModel(
        id: idmed,
        fullName: medico,
        office: descripcionConsultorio,
        fecha: fecha,
        dia: dia,
      );

  /// Convierte horas a TimeSlotModel para compatibilidad con la UI.
  /// NOTA: en el backend, `estado: false` = nadie tomó la ficha (disponible),
  ///       `estado: true` = ficha ya tomada (no disponible).
  List<TimeSlotModel> toTimeSlots() => horas
      .map((h) => TimeSlotModel(
            time: h.hora,
            isAvailable: !h.estado, // false del backend = disponible
            statusLevel: !h.estado ? 'high' : 'none',
            idhora: h.idhora,
            numero: h.numero,
          ))
      .toList();

  /// Fichas disponibles (oferta - demanda).
  int get fichasDisponibles => oferta - demanda;
}

/// Hora individual de la agenda médica.
class HoraDisponibleModel {
  final String idhora;
  final int numero;
  final String hora;
  final bool estado;

  const HoraDisponibleModel({
    required this.idhora,
    required this.numero,
    required this.hora,
    required this.estado,
  });

  factory HoraDisponibleModel.fromJson(Map<String, dynamic> json) {
    return HoraDisponibleModel(
      idhora: json['idhora'] as String? ?? '',
      numero: json['numero'] as int? ?? 0,
      hora: json['hora'] as String? ?? '',
      estado: json['estado'] as bool? ?? false,
    );
  }
}
