import 'beneficiary_model.dart';

class UserModel {
  final String id;
  final String fullName;
  final String rank;
  final String matricula;
  final String bloodType;
  final int age;
  final String role;
  final bool isEnabled;
  final bool hasMedicalAppointment;
  final String email;
  final String phone;
  final List<BeneficiaryModel> beneficiaries;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.rank,
    required this.matricula,
    required this.bloodType,
    required this.age,
    required this.role,
    this.isEnabled = true,
    this.hasMedicalAppointment = false,
    this.email = '',
    this.phone = '',
    required this.beneficiaries,
  });

  /// Nombre con rango para mostrar en UI.
  String get displayName =>
      rank.isEmpty ? fullName : '$rank $fullName';
}
