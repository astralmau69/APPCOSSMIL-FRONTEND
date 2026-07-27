import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../session/user_session.dart';
import '../models/user_model.dart';
import '../models/beneficiary_model.dart';
import 'security_service.dart';
import 'auth_service.dart';
import 'api_client.dart';
import '../constants/api_constants.dart';
import '../utils/web_local_storage.dart';
import '../utils/web_secure_storage.dart';

/// Persiste y restaura los datos esenciales del usuario autenticado
/// en [FlutterSecureStorage] para que la app pueda arrancar sin re-login.
///
/// Flujo:
///   1. Login exitoso → [saveUserSession] guarda UserModel como JSON.
///   2. App reabre con token válido → [restoreUserSession] restaura
///      UserSession.currentUser y SecurityService.displayName/photo.
///   3. Logout → [clearUserSession] borra todo.
class SessionRestoreService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyUserData = 'user_session_data';
  static const _keyStoredUsername = 'stored_login_username';
  static const _keyStoredPassword = 'stored_login_password';

  /// Lee una clave con reintentos. Tras reiniciar el dispositivo la primera
  /// lectura del Keystore puede fallar de forma transitoria; reintentar evita
  /// que la sesión/credenciales se vean como inexistentes y se fuerce un login
  /// completo (matrícula + contraseña) aunque ya estén configurados.
  static Future<String?> _readResilient(String key, {int retries = 2}) async {
    for (int attempt = 0; ; attempt++) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
  }

  // ─── Credenciales para re-autenticación silenciosa ───────────────────────

  /// Guarda las credenciales cifradas para permitir re-login silencioso
  /// al desbloquear con PIN/biometría sin mantener el token del servidor vivo.
  static Future<void> storeCredentials(String username, String password) async {
    // Web: flutter_secure_storage usa crypto.subtle (solo https/localhost).
    // Servido por http://IP el write cuelga el login SIN excepción capturable
    // (la promesa JS muere fuera de la zona Dart). Se usa el mismo esquema que
    // el token: memoria + sessionStorage (se borra al cerrar la pestaña).
    if (kIsWeb) {
      webSecureSet(_keyStoredUsername, username);
      webSecureSet(_keyStoredPassword, password);
      return;
    }
    try {
      await _storage.write(key: _keyStoredUsername, value: username);
      await _storage.write(key: _keyStoredPassword, value: password);
    } catch (_) {}
  }

  /// Lee las credenciales almacenadas. Retorna null si no existen.
  static Future<({String username, String password})?> loadCredentials() async {
    try {
      final u = kIsWeb
          ? webSecureGet(_keyStoredUsername)
          : await _readResilient(_keyStoredUsername);
      final p = kIsWeb
          ? webSecureGet(_keyStoredPassword)
          : await _readResilient(_keyStoredPassword);
      if (u == null || p == null || u.isEmpty || p.isEmpty) return null;
      return (username: u, password: p);
    } catch (_) {
      return null;
    }
  }

  /// Borra las credenciales almacenadas (logout explícito).
  /// Nota: [TokenStorage.wipeAll()] ya las borra al hacer deleteAll(); este
  /// método sirve para borrarlas de forma selectiva si fuera necesario.
  static Future<void> clearCredentials() async {
    if (kIsWeb) {
      webSecureDel(_keyStoredUsername);
      webSecureDel(_keyStoredPassword);
      return;
    }
    await _storage.delete(key: _keyStoredUsername);
    await _storage.delete(key: _keyStoredPassword);
  }

  // ─── Guardar ──────────────────────────────────────────────────────────────

  /// Persiste la sesión completa del usuario.
  /// Llamar desde [AuthService.login] después de construir UserSession.currentUser
  /// (incluyendo la foto si se obtuvo).
  static Future<void> saveUserSession(UserModel user) async {
    try {
      final jsonStr = jsonEncode(user.toJson());
      if (kIsWeb) {
        webLsSet(_keyUserData, jsonStr);
      } else {
        await _storage.write(key: _keyUserData, value: jsonStr);
      }
      if (kDebugMode) {
        debugPrint(
          '💾 SessionRestore: sesión guardada (${jsonStr.length} chars)',
        );
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('❌ SessionRestore: error al guardar sesión: $e');
    }
  }

  // ─── Restaurar ────────────────────────────────────────────────────────────

  /// Restaura UserSession.currentUser desde secure storage.
  /// Retorna true si se restauró exitosamente.
  ///
  /// Si hay matrícula guardada pero la foto está vacía, intenta un
  /// re-fetch silencioso del endpoint de foto para actualizarla.
  static Future<bool> restoreUserSession() async {
    try {
      final jsonStr = kIsWeb
          ? webLsGet(_keyUserData)
          : await _readResilient(_keyUserData);
      if (jsonStr == null || jsonStr.isEmpty) return false;

      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final user = UserModel.fromJson(jsonMap);

      // Parche en caliente para sesiones antiguas: asegurar grado del titular
      final resolvedBeneficiaries = user.beneficiaries.map((b) {
        if (b.isTitular && b.grado.isEmpty) {
          return BeneficiaryModel(
            id: b.id,
            fullName: b.fullName,
            relationship: b.relationship,
            age: b.age,
            gender: b.gender,
            matricula: b.matricula,
            photoBase64: b.photoBase64,
            grado: user.rank,
            serviceStatus: b.serviceStatus,
          );
        }
        return b;
      }).toList();
      final enforcedUser = user.copyWith(beneficiaries: resolvedBeneficiaries);

      // Restaurar el singleton en memoria
      UserSession.currentUser = enforcedUser;

      // Fallback global para displayTitle
      BeneficiaryModel.titularRankFallback = enforcedUser.rank;

      // Sincronizar nombre CON rango militar con SecurityService
      if (enforcedUser.fullName.isNotEmpty) {
        await SecurityService.saveDisplayName(enforcedUser.displayName);
      }

      // Si no hay foto guardada, intentar re-fetch silencioso
      if (user.photoBase64.isEmpty && user.matricula.isNotEmpty) {
        _tryRefreshPhoto(user.matricula);
      }

      // También para beneficiarios que falten
      for (var b in user.beneficiaries) {
        if (b.photoBase64.isEmpty && b.matricula.isNotEmpty) {
          _tryRefreshBeneficiaryPhoto(b);
        }
      }

      if (kDebugMode) {
        debugPrint('✅ SessionRestore: sesión restaurada');
      }
      return true;
    } catch (e) {
      if (kDebugMode)
        debugPrint('❌ SessionRestore: error al restaurar sesión: $e');
      return false;
    }
  }

  /// Intenta obtener la foto del servidor en background (no bloquea el arranque).
  static Future<void> _tryRefreshPhoto(String matricula) async {
    final api = ApiClient();
    try {
      final response = await api.get(ApiConstants.aseguradoTipoGpo(matricula));
      if (response is ApiSuccess && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawPhoto = data['foto2'] as String? ?? '';
        final cleanPhoto = AuthService.cleanBase64(rawPhoto);

        final eBloodType =
            (data['gruposan'] as String? ??
                    data['grupoSanguineo'] as String? ??
                    data['grupo_sanguineo'] as String? ??
                    '')
                .trim();
        final eAllergies =
            (data['alergia'] as String? ??
                    data['alergias'] as String? ??
                    data['allergies'] as String? ??
                    '')
                .trim();
        final eGrado =
            (data['grado']?.toString() ??
                    data['Grado']?.toString() ??
                    data['rango']?.toString() ??
                    data['Rango']?.toString() ??
                    '')
                .trim();
        final eRefe4 = (data['refe4'] as String? ?? '').trim();
        final eFuerza =
            (data['fuerza'] as String? ?? data['desfue'] as String? ?? '')
                .trim();
        final eAbrgra = (data['abrgra']?.toString() ?? '').trim();
        final eTipopersonal = (data['tipopersonal'] as String? ?? '').trim();
        // tipo == 'T' es la fuente autoritativa para Titular (ver auth_service.dart)
        final eTipo = (data['tipo']?.toString() ?? '').trim().toUpperCase();
        final isFotoTitular = eTipo == 'T';
        // Regla JWT-first (igual que auth_service.dart):
        // Solo promover a Titular si el rol guardado es 'Titular' (coincidencia) o
        // estaba vacío/ambiguo. Si el rol guardado es explícitamente un rol de
        // beneficiario (ej. 'ROLE_ASEBEN'), respetamos eso y NO promovemos.
        final savedRoleIsExplicitBeneficiary =
            !UserSession.currentUser.isTitular &&
            UserSession.currentUser.role.isNotEmpty;
        final shouldUpgradeToTitular =
            isFotoTitular &&
            !UserSession.currentUser.isTitular &&
            !savedRoleIsExplicitBeneficiary;

        if (cleanPhoto.isNotEmpty ||
            eBloodType.isNotEmpty ||
            eAllergies.isNotEmpty ||
            eGrado.isNotEmpty ||
            eRefe4.isNotEmpty ||
            eFuerza.isNotEmpty ||
            eTipopersonal.isNotEmpty ||
            shouldUpgradeToTitular) {
          UserSession.currentUser = UserSession.currentUser.copyWith(
            photoBase64: cleanPhoto.isNotEmpty
                ? cleanPhoto
                : UserSession.currentUser.photoBase64,
            bloodType: eBloodType.isNotEmpty
                ? eBloodType
                : UserSession.currentUser.bloodType,
            allergies: eAllergies.isNotEmpty
                ? eAllergies
                : UserSession.currentUser.allergies,
            // tipo='B': guardar abrgra como rank para combinar con fuerza en UI ("SOF.1RO. - EJERCITO").
            rank: (eTipo == 'B')
                ? eAbrgra
                : (eGrado.isNotEmpty ? eGrado : UserSession.currentUser.rank),
            role: shouldUpgradeToTitular ? 'Titular' : null,
            serviceStatus: eRefe4.isNotEmpty
                ? eRefe4
                : UserSession.currentUser.serviceStatus,
            fuerza: eFuerza.isNotEmpty
                ? eFuerza
                : UserSession.currentUser.fuerza,
            tipopersonal: eTipopersonal.isNotEmpty
                ? eTipopersonal
                : UserSession.currentUser.tipopersonal,
          );

          // Si promovimos a Titular y no hay entrada titular en la lista, intentar
          // convertir la entrada self existente (matchea por matrícula).
          final currentBens = UserSession.currentUser.beneficiaries;
          final hasTitularEntry = currentBens.any((b) => b.isTitular);
          List<BeneficiaryModel> updatedBens;
          if (shouldUpgradeToTitular && !hasTitularEntry) {
            final userMatricula = UserSession.currentUser.matricula.trim();
            final userId = UserSession.currentUser.id;
            final selfIdx = currentBens.indexWhere(
              (b) => b.id == userId || b.matricula.trim() == userMatricula,
            );
            if (selfIdx >= 0) {
              final existing = currentBens[selfIdx];
              updatedBens = List<BeneficiaryModel>.from(currentBens);
              updatedBens[selfIdx] = BeneficiaryModel(
                id: existing.id,
                fullName: existing.fullName,
                relationship: 'Titular',
                age: existing.age,
                gender: existing.gender,
                matricula: existing.matricula,
                photoBase64: cleanPhoto.isNotEmpty
                    ? cleanPhoto
                    : existing.photoBase64,
                grado: eGrado.isNotEmpty
                    ? eGrado
                    : (existing.grado.isNotEmpty
                          ? existing.grado
                          : UserSession.currentUser.rank),
                serviceStatus: eRefe4.isNotEmpty
                    ? eRefe4
                    : existing.serviceStatus,
              );
            } else {
              updatedBens = [
                BeneficiaryModel(
                  id: userId,
                  fullName: UserSession.currentUser.fullName,
                  relationship: 'Titular',
                  age: UserSession.currentUser.age,
                  gender: UserSession.currentUser.gender,
                  matricula: userMatricula,
                  photoBase64: cleanPhoto,
                  grado: eGrado.isNotEmpty
                      ? eGrado
                      : UserSession.currentUser.rank,
                  serviceStatus: eRefe4,
                ),
                ...currentBens,
              ];
            }
          } else {
            updatedBens = currentBens.map((b) {
              if (b.isTitular) {
                return BeneficiaryModel(
                  id: b.id,
                  fullName: b.fullName,
                  relationship: b.relationship,
                  age: b.age,
                  gender: b.gender,
                  matricula: b.matricula,
                  photoBase64: cleanPhoto.isNotEmpty
                      ? cleanPhoto
                      : b.photoBase64,
                  grado: eGrado.isNotEmpty ? eGrado : b.grado,
                  serviceStatus: eRefe4.isNotEmpty ? eRefe4 : b.serviceStatus,
                );
              }
              return b;
            }).toList();
          }
          UserSession.currentUser = UserSession.currentUser.copyWith(
            beneficiaries: List<BeneficiaryModel>.from(updatedBens),
          );
          BeneficiaryModel.titularRankFallback = UserSession.currentUser.rank;

          // Persistir la foto actualizada
          await saveUserSession(UserSession.currentUser);
          if (kDebugMode) {
            debugPrint(
              '📸 SessionRestore: foto titular actualizada en background',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SessionRestore: no se pudo actualizar foto titular: $e');
      }
    } finally {
      api.close();
    }
  }

  static Future<void> _tryRefreshBeneficiaryPhoto(
    BeneficiaryModel beneficiary,
  ) async {
    final api = ApiClient();
    try {
      final response = await api.get(
        ApiConstants.aseguradoFoto(beneficiary.matricula),
      );
      if (response is ApiSuccess && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawPhoto = data['foto2'] as String? ?? '';
        final cleanPhoto = AuthService.cleanBase64(rawPhoto);
        final bGrado =
            (data['grado']?.toString() ??
                    data['Grado']?.toString() ??
                    data['rango']?.toString() ??
                    data['Rango']?.toString() ??
                    '')
                .trim();
        final bRefe4 = (data['refe4'] as String? ?? '').trim();
        if (cleanPhoto.isNotEmpty || bGrado.isNotEmpty || bRefe4.isNotEmpty) {
          final updatedBens = UserSession.currentUser.beneficiaries.map((b) {
            if (b.id == beneficiary.id) {
              return BeneficiaryModel(
                id: b.id,
                fullName: b.fullName,
                relationship: b.relationship,
                age: b.age,
                gender: b.gender,
                matricula: b.matricula,
                photoBase64: cleanPhoto.isNotEmpty ? cleanPhoto : b.photoBase64,
                grado: bGrado.isNotEmpty ? bGrado : b.grado,
                serviceStatus: bRefe4.isNotEmpty ? bRefe4 : b.serviceStatus,
              );
            }
            return b;
          }).toList();

          UserSession.currentUser = UserSession.currentUser.copyWith(
            beneficiaries: List<BeneficiaryModel>.from(updatedBens),
          );
          await saveUserSession(UserSession.currentUser);
          if (kDebugMode) {
            debugPrint('📸 SessionRestore: foto de beneficiario actualizada');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '⚠️ SessionRestore: no se pudo actualizar foto de beneficiario: $e',
        );
      }
    } finally {
      api.close();
    }
  }

  // ─── Obtener matrícula (para validación de token) ─────────────────────────

  /// Retorna la matrícula guardada sin restaurar toda la sesión.
  static Future<String?> getMatricula() async {
    try {
      final jsonStr = kIsWeb
          ? webLsGet(_keyUserData)
          : await _readResilient(_keyUserData);
      if (jsonStr == null) return null;
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return jsonMap['matricula'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Limpiar ──────────────────────────────────────────────────────────────

  /// Borra la sesión persistida. Llamar siempre en logout.
  static Future<void> clearUserSession() async {
    if (kIsWeb) {
      webLsDel(_keyUserData);
      return;
    }
    await _storage.delete(key: _keyUserData);
  }
}
