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

  /// e.g. "Hosp. Militar Central — La Paz"
  String get displayName => '$shortName — $city';
}
