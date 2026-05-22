import '../extensions/string_extensions.dart';

class HospitalModel {
  final String id;
  final String name;
  final String shortName;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;
  final String photoBase64;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.city,
    required this.address,
    this.latitude,
    this.longitude,
    this.photoBase64 = '',
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    double? rawLat = json['latitud'] != null ? double.tryParse(json['latitud'].toString()) : json['latitude'] as double?;
    double? rawLng = json['longitud'] != null ? double.tryParse(json['longitud'].toString()) : json['longitude'] as double?;

    if (rawLat != null && rawLng != null) {
      // Corrección de error de backend: latitud y longitud invertidos (Longitud de Bolivia es -57 a -69)
      if (rawLat < -45 || rawLat > 45) {
        final temp = rawLat;
        rawLat = rawLng;
        rawLng = temp;
      }
      // Corrección de signo: Bolivia está en el hemisferio sur y oeste (ambos negativos)
      if (rawLat > 0) rawLat = -rawLat;
      if (rawLng > 0) rawLng = -rawLng;
    }

    return HospitalModel(
      id: (json['idsuc'] ?? json['id'] ?? '').toString(),
      name: (json['sucursal'] as String? ?? json['name'] as String? ?? '').toDisplayCase,
      shortName: json['sigla'] as String? ?? json['sucursal_corto'] as String? ?? json['shortName'] as String? ?? '',
      city: (json['ciudad'] as String? ?? json['city'] as String? ?? '').toDisplayCase,
      address: (json['direccion'] as String? ?? json['address'] as String? ?? '').toDisplayCase,
      latitude: rawLat,
      longitude: rawLng,
      photoBase64: json['foto'] as String? ?? '',
    );
  }

  /// e.g. "Hospital Militar Central — La Paz"
  String get displayName => '$name — $city';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'city': city,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'foto': photoBase64,
      };
}
