import '../extensions/string_extensions.dart';

class BeneficiaryModel {
  final String id;
  final String fullName;
  final String relationship;
  final String matricula;
  final String photoBase64;
  final int? age;
  final String gender;

  const BeneficiaryModel({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.matricula = '',
    this.photoBase64 = '',
    this.age,
    this.gender = '',
  });

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) {
    // Construir nombre completo desde pat/mat/nom si no viene directo
    String fullName = (json['nombre_completo'] as String? ??
        json['fullName'] as String? ??
        '').trim();
    if (fullName.isEmpty) {
      final pat = (json['pat'] as String? ?? '').trim();
      final mat = (json['mat'] as String? ?? '').trim();
      final nom = (json['nom'] as String? ?? '').trim();
      if (nom.isNotEmpty || pat.isNotEmpty || mat.isNotEmpty) {
        fullName = [nom, pat, mat].where((s) => s.isNotEmpty).join(' ');
      }
    }

    return BeneficiaryModel(
      id: (json['idper'] ?? json['idben'] ?? json['id'] ?? '').toString(),
      fullName: fullName.toDisplayCase,
      relationship: (json['parentesco'] as String? ??
          json['relationship'] as String? ??
          '').trim().toDisplayCase,
      matricula: (json['mtrben'] ??
                  json['matricula'] ??
                  json['nromatricula'] ??
                  json['nromat'] ??
                  json['codigo'] ??
                  '').toString().trim(),
      photoBase64: (json['foto'] as String? ??
                   json['foto2'] as String? ??
                   json['foto_base64'] as String? ??
                   '').trim(),
      age: json['edad'] as int? ?? json['age'] as int?,
      gender: (json['sexo'] as String? ??
              json['genero'] as String? ??
              json['gender'] as String? ??
              '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'relationship': relationship,
        'matricula': matricula,
        'photoBase64': photoBase64,
        'age': age,
        'gender': gender,
      };

  /// First letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0] : '?';

  /// Whether this beneficiary is the account holder.
  bool get isTitular => relationship.toUpperCase() == 'TITULAR';

  /// Infiere género a partir del parentesco si no viene explícito del backend.
  ///
  /// Útil cuando el backend no envía `genero` para beneficiarios pero sí
  /// envía `parentesco` (Esposa, Hija, Hijo, etc.).
  String get effectiveGender {
    if (gender.isNotEmpty) return gender.toUpperCase();
    final rel = relationship.toUpperCase();
    if (rel.contains('ESPOSA') || rel.contains('HIJA') || rel.contains('MADRE')) return 'FEMENINO';
    if (rel.contains('ESPOSO') || rel.contains('HIJO') || rel.contains('PADRE')) return 'MASCULINO';
    return '';
  }
}
