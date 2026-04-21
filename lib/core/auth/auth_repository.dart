import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/session_restore_service.dart';
import '../session/user_session.dart';
import '../storage/token_storage.dart';
import '../utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  REPOSITORIO DE AUTENTICACIÓN
//
//  Problema que resuelve:
//    El logout estaba disperso en 4 lugares distintos del código.
//    Cualquier pantalla que quisiera cerrar sesión necesitaba conocer
//    TokenStorage, UserSession, SessionRestoreService y SecurityService.
//    Este repositorio encapsula esa orquestación en un único lugar.
//
//  Responsabilidades:
//    - Login  → delega en AuthService (OAuth2 Password Grant ya implementado)
//    - Logout → ejecuta la secuencia atómica de limpieza de sesión
//    - Consulta de sesión activa → lee el token de TokenStorage
//
//  Lo que NO hace:
//    - No reemplaza AuthService (que mantiene toda la lógica OAuth2 y UI).
//    - No borra el PIN ni la biometría del usuario al cerrar sesión
//      (esos datos pertenecen al dispositivo, no a la sesión de red).
//    - No gestiona el estado visual de la pantalla (eso es responsabilidad
//      de los screens / shell).
// ─────────────────────────────────────────────────────────────────────────────

// ─── CONTRATO ────────────────────────────────────────────────────────────────

/// Interfaz del repositorio de autenticación.
///
/// Abstrae OAuth2, almacenamiento seguro y estado de sesión detrás de
/// tres operaciones bien definidas.
///
/// Implementaciones:
///   - [AuthRepositoryImpl] → producción
///   - Clase mock → tests unitarios (implementa esta interfaz)
abstract interface class AuthRepository {
  /// Autentica al usuario contra el backend Spring Boot con OAuth2
  /// Password Grant y persiste el JWT en almacenamiento seguro.
  ///
  /// Retorna [AuthSuccess] con el [AuthTokenModel] si el login fue
  /// exitoso, o [AuthError] con el mensaje y [AuthErrorType] si falló.
  ///
  /// Flujo interno (delegado a [AuthService]):
  ///   POST /api/security/oauth/token
  ///   → Guarda access_token + refresh_token (TokenStorage)
  ///   → Construye UserSession.currentUser
  ///   → Persiste sesión en SecureStorage (SessionRestoreService)
  Future<AuthResult> login({
    required String matricula,
    required String password,
  });

  /// Cierra la sesión de forma atómica en el siguiente orden:
  ///
  ///   1. [TokenStorage.deleteToken]              — revoca JWT local
  ///   2. [SessionRestoreService.clearCredentials] — borra usuario/contraseña cifrados
  ///   3. [SessionRestoreService.clearUserSession] — borra JSON de sesión persistida
  ///   4. [UserSession.clear]                      — limpia el singleton en memoria
  ///
  /// Orden deliberado: los tokens de red se borran primero. Si la app
  /// crashea a mitad del proceso, el siguiente arranque no encontrará
  /// tokens válidos y redirigirá al login.
  ///
  /// ⚠ No borra el PIN ni la biometría — son datos del dispositivo que
  /// deben persistir entre sesiones para el flujo de desbloqueo local.
  Future<void> logout();

  /// Retorna `true` si existe un access_token válido en almacenamiento seguro.
  ///
  /// No valida la firma del token contra el backend; solo verifica que
  /// el campo no esté vacío. Para una validación real usar el endpoint
  /// `/verifica-validaciones` después de restaurar la sesión.
  Future<bool> hasActiveSession();
}

// ─── IMPLEMENTACIÓN ──────────────────────────────────────────────────────────

/// Implementación de producción del [AuthRepository].
///
/// Inyección de dependencias:
/// ```dart
/// // Uso normal (producción)
/// final repo = AuthRepositoryImpl();
///
/// // Uso en tests con AuthService mockeado
/// final repo = AuthRepositoryImpl(authService: MockAuthService());
/// ```
class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;

  AuthRepositoryImpl({AuthService? authService})
      : _authService = authService ?? AuthService();

  // ── Login ───────────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> login({
    required String matricula,
    required String password,
  }) async {
    AppLogger.info('AUTH_REPO', 'Iniciando login para matrícula: $matricula');

    final result = await _authService.login(
      username: matricula,
      password: password,
    );

    if (kDebugMode) {
      switch (result) {
        case AuthSuccess():
          AppLogger.info('AUTH_REPO', 'Login exitoso');
        case AuthError(:final message, :final type):
          AppLogger.warn('AUTH_REPO', 'Login fallido [$type]: $message');
      }
    }

    return result;
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  @override
  Future<void> logout() async {
    AppLogger.info('AUTH_REPO', 'Iniciando logout atómico...');

    try {
      // Paso 1 y 2 en paralelo: borrar tokens y credenciales almacenadas.
      // Son operaciones independientes sobre distintas keys del secure storage.
      await Future.wait([
        TokenStorage.deleteToken(),
        SessionRestoreService.clearCredentials(),
      ]);

      // Paso 3: borrar el JSON completo de sesión del usuario.
      // Se hace secuencialmente después para garantizar que los tokens
      // ya no son recuperables si falla este paso.
      await SessionRestoreService.clearUserSession();

      // Paso 4: limpiar el singleton en memoria (sincrónico, siempre último).
      UserSession.clear();

      AppLogger.info('AUTH_REPO', 'Logout completado — sesión limpia');
    } catch (e) {
      // Incluso si falla el storage, el singleton en memoria se limpia.
      // En el próximo arranque, la ausencia de token redirigirá al login.
      AppLogger.error('AUTH_REPO', 'Error durante logout: $e');
      UserSession.clear();
      rethrow;
    }
  }

  // ── Sesión activa ───────────────────────────────────────────────────────────

  @override
  Future<bool> hasActiveSession() => TokenStorage.hasToken();
}
