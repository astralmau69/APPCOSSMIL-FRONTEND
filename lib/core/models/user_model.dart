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
  final String ci;
  final String photoBase64;
  final String birthDate;
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
    this.ci = '',
    this.photoBase64 = '',
    this.birthDate = '',
    required this.beneficiaries,
  });

  UserModel copyWith({
    String? id,
    String? fullName,
    String? rank,
    String? matricula,
    String? bloodType,
    int? age,
    String? role,
    bool? isEnabled,
    bool? hasMedicalAppointment,
    String? email,
    String? phone,
    String? ci,
    String? photoBase64,
    String? birthDate,
    List<BeneficiaryModel>? beneficiaries,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      rank: rank ?? this.rank,
      matricula: matricula ?? this.matricula,
      bloodType: bloodType ?? this.bloodType,
      age: age ?? this.age,
      role: role ?? this.role,
      isEnabled: isEnabled ?? this.isEnabled,
      hasMedicalAppointment:
          hasMedicalAppointment ?? this.hasMedicalAppointment,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      ci: ci ?? this.ci,
      photoBase64: photoBase64 ?? this.photoBase64,
      birthDate: birthDate ?? this.birthDate,
      beneficiaries: beneficiaries ?? this.beneficiaries,
    );
  }

  /// Nombre con rango para mostrar en UI.
  String get displayName =>
      rank.isEmpty ? fullName : '$rank $fullName';
}
