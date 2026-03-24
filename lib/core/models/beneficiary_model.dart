class BeneficiaryModel {
  final String id;
  final String fullName;
  final String relationship;
  final String matricula;
  final String photoBase64;
  final int? age;

  const BeneficiaryModel({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.matricula = '',
    this.photoBase64 = '',
    this.age,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'relationship': relationship,
        'matricula': matricula,
        'photoBase64': photoBase64,
        'age': age,
      };

  /// First letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0] : '?';

  /// Whether this beneficiary is the account holder.
  bool get isTitular => relationship == 'Titular';
}
