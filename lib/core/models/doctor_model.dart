import '../extensions/string_extensions.dart';

class DoctorModel {
  final String id;
  final String fullName;
  final String office;
  final String fecha;
  final String dia;
  final String foto;

  const DoctorModel({
    required this.id,
    required this.fullName,
    required this.office,
    this.fecha = '',
    this.dia = '',
    this.foto = '',
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: (json['idmed'] ?? json['id'] ?? '').toString(),
      fullName: (json['nombre_completo'] as String? ??
          json['fullName'] as String? ??
          '').toDisplayCase,
      office: (json['consultorio'] as String? ??
          json['office'] as String? ??
          '').toDisplayCase,
      fecha: json['fecha'] as String? ?? '',
      dia: json['dia'] as String? ?? '',
      foto: json['foto'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'office': office,
      };
}
