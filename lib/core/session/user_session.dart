import '../models/user_model.dart';
import '../models/beneficiary_model.dart';

/// Singleton que mantiene los datos del usuario autenticado en memoria.
///
/// Poblado por [AuthService.login] y [SessionRestoreService.restoreUserSession].
/// Consumido por pantallas y servicios para acceder al usuario actual.
///
/// No confundir con mock data — estos son datos reales del OAuth/login.
class UserSession {
  UserSession._();

  /// Datos del usuario actualmente autenticado.
  ///
  /// Se inicializa con un usuario vacío y se reemplaza tras login o
  /// restauración de sesión desde secure storage.
  static UserModel currentUser = const UserModel(
    id: '',
    fullName: '',
    rank: '',
    matricula: '',
    bloodType: '',
    age: 0,
    gender: '',
    role: '',
    isEnabled: false,
    beneficiaries: [],
  );

  /// Limpia la sesión actual (llamar en logout).
  static void clear() {
    currentUser = const UserModel(
      id: '',
      fullName: '',
      rank: '',
      matricula: '',
      bloodType: '',
      age: 0,
      gender: '',
      role: '',
      isEnabled: false,
      beneficiaries: [],
    );
  }

  /// Obtiene la edad aplicable para el filtro (titular o beneficiario).
  static int ageFor(BeneficiaryModel? beneficiary) {
    if (beneficiary == null || beneficiary.relationship == 'Titular') {
      return currentUser.age;
    }
    // Si es beneficiario y no tiene edad, no deberíamos usar la del titular.
    // Retornamos 0 para que los filtros de pediatría/ginecología actúen con cautela.
    return beneficiary.age ?? 0;
  }

  /// Obtiene el género aplicable para el filtro.
  static String genderFor(BeneficiaryModel? beneficiary) {
    if (beneficiary == null || beneficiary.relationship == 'Titular') {
      return currentUser.gender;
    }
    
    // Usar género efectivo (basado en parentesco si el campo 'gender' es nulo)
    if (beneficiary.effectiveGender.isNotEmpty) {
      return beneficiary.effectiveGender;
    }
    
    // Fallback final: si no hay datos, retornamos vacío para no sesgar el filtro
    return beneficiary.gender.isNotEmpty ? beneficiary.gender : '';
  }
}
