/// Modelo de horario de atención habilitado para reservas.
class HorarioAtencionModel {
  final int idhorario;
  final String descripcion;
  final String horaini;
  final String horafin;

  const HorarioAtencionModel({
    required this.idhorario,
    required this.descripcion,
    required this.horaini,
    required this.horafin,
  });

  factory HorarioAtencionModel.fromJson(Map<String, dynamic> json) {
    return HorarioAtencionModel(
      idhorario: json['idhorario'] as int? ?? 0,
      descripcion: json['descripcion'] as String? ?? '',
      horaini: json['horaini'] as String? ?? '',
      horafin: json['horafin'] as String? ?? '',
    );
  }

  /// Rango legible: "08:00 - 12:00"
  String get rangoHorario {
    final ini = horaini.length >= 5 ? horaini.substring(0, 5) : horaini;
    final fin = horafin.length >= 5 ? horafin.substring(0, 5) : horafin;
    if (ini.isEmpty && fin.isEmpty) return 'Horario no disponible';
    return '$ini - $fin';
  }
}
