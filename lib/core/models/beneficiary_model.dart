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
    return BeneficiaryModel(
      id: (json['idben'] ?? json['id'] ?? '').toString(),
      fullName: json['nombre_completo'] as String? ??
          json['fullName'] as String? ??
          '',
      relationship: json['parentesco'] as String? ??
          json['relationship'] as String? ??
          '',
      matricula: (json['matricula'] ??
                  json['nromatricula'] ??
                  json['nromat'] ??
                  json['codigo'] ??
                  '').toString().trim(),
      photoBase64: json['foto2'] as String? ??
                   json['foto_base64'] as String? ??
                   json['foto'] as String? ??
                   '',
      age: json['edad'] as int? ?? json['age'] as int?,
      gender: json['genero'] as String? ??
              json['sexo'] as String? ??
              json['gender'] as String? ??
              '',
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
  bool get isTitular => relationship == 'Titular';

  /// Infiere género a partir del parentesco si no viene explícito del backend.
  ///
  /// Útil cuando el backend no envía `genero` para beneficiarios pero sí
  /// envía `parentesco` (Esposa, Hija, Hijo, etc.).
  String get effectiveGender {
    if (gender.isNotEmpty) return gender;
    final rel = relationship.toLowerCase().trim();
    if (rel == 'esposa' || rel == 'hija' || rel == 'madre') return 'FEMENINO';
    if (rel == 'esposo' || rel == 'hijo' || rel == 'padre') return 'MASCULINO';
    return '';
  }
}
