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
    // Si viene una lista de sucursales subordinada (formato agrupado por depto)
    if (json.containsKey('sucursales') && json['sucursales'] is List) {
      final sucursales = json['sucursales'] as List<dynamic>;
      return RegionalModel(
        id: (json['iddepto'] ?? json['idreg'] ?? json['id'] ?? '').toString(),
        name: json['departamento'] as String? ?? json['regional'] as String? ?? json['name'] as String? ?? '',
        hospitals: sucursales
            .map((s) => HospitalModel.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
    }
    
    // Si es un objeto de sucursal directo (formato plano)
    if (json.containsKey('idsuc') || json.containsKey('sucursal')) {
      final hospital = HospitalModel.fromJson(json);
      return RegionalModel(
        id: 'flat_${hospital.id}',
        name: hospital.name,
        hospitals: [hospital],
      );
    }

    return RegionalModel(
      id: (json['idreg'] ?? json['id'] ?? '').toString(),
      name: json['regional'] as String? ?? json['name'] as String? ?? '',
      hospitals: [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'hospitals': hospitals.map((h) => h.toJson()).toList(),
      };
}
