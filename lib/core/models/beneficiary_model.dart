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

  /// First letter of name for avatar display.
  String get initial => fullName.isNotEmpty ? fullName[0] : '?';

  /// Whether this beneficiary is the account holder.
  bool get isTitular => relationship == 'Titular';
}
