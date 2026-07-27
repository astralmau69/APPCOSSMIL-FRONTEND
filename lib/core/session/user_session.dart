import 'package:flutter/foundation.dart';
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

  /// Usuario vacío base (antes del login / tras logout).
  static const UserModel _empty = UserModel(
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

  /// Notificador reactivo del usuario actual.
  ///
  /// La UI puede escucharlo con [ValueListenableBuilder] para refrescarse
  /// cuando datos que llegan en SEGUNDO PLANO tras el login (la foto, grupo
  /// sanguíneo, alergias, etc.) actualizan al usuario. Cada asignación a
  /// [currentUser] dispara la notificación automáticamente.
  static final ValueNotifier<UserModel> userNotifier = ValueNotifier<UserModel>(
    _empty,
  );

  /// Datos del usuario actualmente autenticado.
  ///
  /// Se inicializa con un usuario vacío y se reemplaza tras login o
  /// restauración de sesión desde secure storage.
  static UserModel get currentUser => userNotifier.value;
  static set currentUser(UserModel user) => userNotifier.value = user;

  /// true si hay un usuario autenticado en memoria.
  /// Falso justo después de [clear()] o antes del primer login.
  static bool get isLoggedIn => currentUser.id.isNotEmpty;

  /// Limpia la sesión actual (llamar en logout).
  static void clear() {
    currentUser = _empty;
  }

  /// Obtiene la edad aplicable para el filtro (titular o beneficiario).
  static int ageFor(BeneficiaryModel? beneficiary) {
    if (beneficiary == null || beneficiary.isTitular) {
      return currentUser.age;
    }
    // Si es beneficiario y no tiene edad, no deberíamos usar la del titular.
    // Retornamos 0 para que los filtros de pediatría/ginecología actúen con cautela.
    return beneficiary.age ?? 0;
  }

  /// Obtiene el género aplicable para el filtro.
  static String genderFor(BeneficiaryModel? beneficiary) {
    if (beneficiary == null || beneficiary.isTitular) {
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
