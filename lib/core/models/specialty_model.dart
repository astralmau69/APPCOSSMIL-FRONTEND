import '../extensions/string_extensions.dart';

class SpecialtyModel {
  final String id;
  final String name;
  final String description;
  final bool isInterconsulta;
  final bool isAuthorized;
  final String? referredBy;

  const SpecialtyModel({
    required this.id,
    required this.name,
    required this.description,
    this.isInterconsulta = false,
    this.isAuthorized = false,
    this.referredBy,
  });

  factory SpecialtyModel.fromJson(Map<String, dynamic> json) {
    return SpecialtyModel(
      id: (json['idesp'] ?? json['id'] ?? '').toString(),
      name: (json['especialidad'] as String? ?? json['name'] as String? ?? '').toDisplayCase,
      description: (json['descripcion'] as String? ?? json['description'] as String? ?? '').toDisplayCase,
      isInterconsulta: json['interconsulta'] as bool? ?? false,
      isAuthorized: json['autorizada'] as bool? ?? false,
      referredBy: json['referido_por'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'isInterconsulta': isInterconsulta,
        'isAuthorized': isAuthorized,
        'referredBy': referredBy,
      };
}
