class HospitalModel {
  final String id;
  final String name;
  final String shortName;
  final String city;
  final String address;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    required this.address,
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: (json['idsuc'] ?? json['id'] ?? '').toString(),
      name: json['sucursal'] as String? ?? json['name'] as String? ?? '',
      shortName: json['sucursal_corto'] as String? ?? json['shortName'] as String? ?? '',
      city: json['ciudad'] as String? ?? json['city'] as String? ?? '',
      address: json['direccion'] as String? ?? json['address'] as String? ?? '',
    );
  }

  /// e.g. "Hosp. Militar Central — La Paz"
  String get displayName => '$shortName — $city';
}
