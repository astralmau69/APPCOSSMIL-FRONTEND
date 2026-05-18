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
  /// Celular del afiliado devuelto por el endpoint de foto/perfil (campo numcel).
  final String numCel;
  /// Fuerza/rama militar (ej. "EJERCITO", "ARMADA", "FUERZA AÉREA").
  final String fuerza;
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
    this.numCel = '',
    this.fuerza = '',
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
    String? numCel,
    String? fuerza,
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
      numCel: numCel ?? this.numCel,
      fuerza: fuerza ?? this.fuerza,
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
      numCel: (json['numCel'] as String? ?? json['numcel'] as String? ?? '').trim(),
      fuerza: (json['fuerza'] as String? ?? '').trim(),
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
        'numCel': numCel,
        'fuerza': fuerza,
        'beneficiaries': beneficiaries.map((b) => b.toJson()).toList(),
      };

  /// Nombre con tratamiento Sr./Sra. para UI.
  ///
  /// El grado militar NO se aplica como prefijo del nombre — se muestra como
  /// label separado "Grado del titular · …" en home y perfil. Esto vale tanto
  /// para titulares como para beneficiarios.
  String get displayName => RankUtils.displayNameWithPrefix(
    fullName: fullName,
    isTitular: isTitular,
    grado: '',
    age: age,
    gender: gender,
  );

  /// Grado para mostrar en chips del perfil/tarjeta.
  ///
  /// - Titular → su rango (ej. "Cnl.").
  /// - Beneficiario con rango heredado del backend → mismo rango con prefijo
  ///   "Tit. " para dejar explícito que pertenece al titular del seguro y no
  ///   al beneficiario logueado (ej. "Tit. Cnl.").
  /// - Sin rango militar válido → vacío.
  String get rankDisplay {
    if (!RankUtils.isValidRankForDisplay(rank)) return '';
    return isTitular ? rank : 'Tit. $rank';
  }

  /// `true` si el usuario logueado es titular del seguro.
  ///
  /// Jerarquía de decisión:
  ///   1. Si la lista familiar **tiene** entradas → busca el propio `id`
  ///      y delega en `b.isTitular`. Esto evita que el campo `role` del JWT
  ///      sobrescriba la fuente de verdad del backend.
  ///   2. Si **no hay grupo familiar** (lista vacía) → el usuario es siempre
  ///      titular (nunca hereda el grado de otro). Se usa `role` como
  ///      confirmación adicional, pero si el backend no lo devuelve el usuario
  ///      sigue siendo considerado titular de su propio seguro.
  bool get isTitular {
    if (beneficiaries.isNotEmpty) {
      for (final b in beneficiaries) {
        if (b.id == id) return b.isTitular;
      }
      // El id no aparece en la lista familiar → usar role como fallback.
      return role == 'Titular';
    }
    // Sin grupo familiar: usar el role del JWT como fuente de verdad.
    // Un beneficiario cuyo endpoint gpo-familiar devuelve [] también llega aquí,
    // y su role es 'ROLE_ASEBEN' (u otro rol de beneficiario), no 'Titular'.
    return role == 'Titular';
  }
}
