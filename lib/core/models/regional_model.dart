import 'hospital_model.dart';

class RegionalModel {
  final String id;
  final String name;
  final List<HospitalModel> hospitals;

  const RegionalModel({
    required this.id,
    required this.name,
    required this.hospitals,
  });

  factory RegionalModel.fromJson(Map<String, dynamic> json) {
    final sucursales = json['sucursales'] as List<dynamic>? ?? [];
    return RegionalModel(
      id: (json['idreg'] ?? json['id'] ?? '').toString(),
      name: json['regional'] as String? ?? json['name'] as String? ?? '',
      hospitals: sucursales
          .map((s) => HospitalModel.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
