import '../extensions/string_extensions.dart';
import '../utils/rank_utils.dart';
import 'beneficiary_model.dart';

class UserModel {
  final String id;
  final String fullName;
  final String rank;
  final String matricula;
  final String bloodType;
  final int age;
  final String gender;
  final String role;
  final bool isEnabled;
  final bool hasMedicalAppointment;
  final String email;
  final String phone;
  final String ci;
  final String photoBase64;
  final String birthDate;
  final int? idseg;
  final String? uc;
  final String allergies;
  /// Estado de servicio del endpoint de foto (refe4). Ej: "ACTIVO", "PASIVO".
  final String serviceStatus;
  /// Teléfono de emergencia registrado en el backend (campo telfemerg).
  final String emergencyPhone;
  /// Dirección o referencia domiciliaria registrada en el backend.
  final String referencia;
  final List<BeneficiaryModel> beneficiaries;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.rank,
    required this.matricula,
    required this.bloodType,
    required this.age,
    this.gender = '',
    required this.role,
    this.isEnabled = true,
    this.hasMedicalAppointment = false,
    this.email = '',
    this.phone = '',
    this.ci = '',
    this.photoBase64 = '',
    this.birthDate = '',
    this.idseg,
    this.uc,
    this.allergies = '',
    this.serviceStatus = '',
    this.emergencyPhone = '',
    this.referencia = '',
    required this.beneficiaries,
  });

  UserModel copyWith({
    String? id,
    String? fullName,
    String? rank,
    String? matricula,
    String? bloodType,
    int? age,
    String? gender,
    String? role,
    bool? isEnabled,
    bool? hasMedicalAppointment,
    String? email,
    String? phone,
    String? ci,
    String? photoBase64,
    String? birthDate,
    int? idseg,
    String? uc,
    String? allergies,
    String? serviceStatus,
    String? emergencyPhone,
    String? referencia,
    List<BeneficiaryModel>? beneficiaries,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      rank: rank ?? this.rank,
      matricula: matricula ?? this.matricula,
      bloodType: bloodType ?? this.bloodType,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      isEnabled: isEnabled ?? this.isEnabled,
      hasMedicalAppointment:
          hasMedicalAppointment ?? this.hasMedicalAppointment,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      ci: ci ?? this.ci,
      photoBase64: photoBase64 ?? this.photoBase64,
      birthDate: birthDate ?? this.birthDate,
      idseg: idseg ?? this.idseg,
      uc: uc ?? this.uc,
      allergies: allergies ?? this.allergies,
      serviceStatus: serviceStatus ?? this.serviceStatus,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      referencia: referencia ?? this.referencia,
      beneficiaries: beneficiaries ?? this.beneficiaries,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['idper'] ?? json['id'] ?? '').toString(),
      fullName: (json['nombre_completo'] as String? ??
          json['fullName'] as String? ??
          '').toDisplayCase,
      rank: () {
        final r = (json['grado'] as String? ?? json['rank'] as String? ?? '').toDisplayCase.trim();
        return r.isNotEmpty ? r : 'Asegurado';
      }(),
      matricula: json['matricula'] as String? ?? '',
      bloodType: json['tipo_sangre'] as String? ??
          json['bloodType'] as String? ??
          '',
      age: json['edad'] as int? ?? json['age'] as int? ?? 0,
      gender: json['genero'] as String? ?? json['gender'] as String? ?? '',
      role: json['rol'] as String? ?? json['role'] as String? ?? '',
      isEnabled: json['habilitado'] as bool? ??
          json['isEnabled'] as bool? ??
          true,
      hasMedicalAppointment: json['tiene_cita'] as bool? ??
          json['hasMedicalAppointment'] as bool? ??
          false,
      email: json['correo'] as String? ?? json['email'] as String? ?? '',
      phone: json['celular'] as String? ?? json['phone'] as String? ?? '',
      ci: json['ci'] as String? ?? '',
      photoBase64: json['foto2'] as String? ??
          json['photoBase64'] as String? ??
          '',
      birthDate:
          json['fecnac'] as String? ?? json['birthDate'] as String? ?? '',
      beneficiaries: (json['beneficiarios'] as List<dynamic>?)
              ?.map(
                  (e) => BeneficiaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          (json['beneficiaries'] as List<dynamic>?)
              ?.map(
                  (e) => BeneficiaryModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      allergies: (json['alergias'] as String? ??
          json['allergies'] as String? ??
          '').toDisplayCase,
      serviceStatus: json['serviceStatus'] as String? ?? json['refe4'] as String? ?? '',
      emergencyPhone: json['emergencyPhone'] as String? ?? json['telfemerg'] as String? ?? '',
      referencia: json['referencia'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'rank': rank,
        'matricula': matricula,
        'bloodType': bloodType,
        'age': age,
        'gender': gender,
        'role': role,
        'isEnabled': isEnabled,
        'hasMedicalAppointment': hasMedicalAppointment,
        'email': email,
        'phone': phone,
        'ci': ci,
        'photoBase64': photoBase64,
        'birthDate': birthDate,
        'allergies': allergies,
        'serviceStatus': serviceStatus,
        'emergencyPhone': emergencyPhone,
        'referencia': referencia,
        'beneficiaries': beneficiaries.map((b) => b.toJson()).toList(),
      };

  /// Nombre con rango abreviado (titular) o tratamiento (beneficiario) para UI.
  String get displayName => RankUtils.displayNameWithPrefix(
    fullName: fullName,
    isTitular: isTitular,
    grado: rank,
    age: age,
    gender: gender,
  );

  /// Shortcut para verificar si el rol es Titular
  bool get isTitular => role == 'Titular';
}
