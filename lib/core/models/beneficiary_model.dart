class BeneficiaryModel {
  final String id;
  final String fullName;
  final String relationship;
  final int? age;

  const BeneficiaryModel({
    required this.id,
    required this.fullName,
    required this.relationship,
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
      age: json['edad'] as int? ?? json['age'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'relationship': relationship,
        'age': age,
      };

  /// First letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0] : '?';

  /// Whether this beneficiary is the account holder.
  bool get isTitular => relationship == 'Titular';
}
