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
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyUserData = 'user_session_data';

  // ─── Guardar ──────────────────────────────────────────────────────────────

  /// Persiste la sesión completa del usuario.
  /// Llamar desde [AuthService.login] después de construir UserSession.currentUser
  /// (incluyendo la foto si se obtuvo).
  static Future<void> saveUserSession(UserModel user) async {
    try {
      final jsonStr = jsonEncode(user.toJson());
      await _storage.write(key: _keyUserData, value: jsonStr);
      if (kDebugMode) {
        debugPrint('💾 SessionRestore: sesión guardada (${jsonStr.length} chars)');
      }
    } catch (e) {
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
      final jsonStr = await _storage.read(key: _keyUserData);
      if (jsonStr == null || jsonStr.isEmpty) return false;

      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final user = UserModel.fromJson(jsonMap);

      // Restaurar el singleton en memoria
      UserSession.currentUser = user;

      // Sincronizar nombre con SecurityService
      if (user.fullName.isNotEmpty) {
        await SecurityService.saveDisplayName(user.fullName);
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
        debugPrint('✅ SessionRestore: sesión restaurada para ${user.fullName}');
      }
      return true;
    } catch (e) {
      debugPrint('❌ SessionRestore: error al restaurar sesión: $e');
      return false;
    }
  }

  /// Intenta obtener la foto del servidor en background (no bloquea el arranque).
  static Future<void> _tryRefreshPhoto(String matricula) async {
    final api = ApiClient();
    try {
      final response = await api.get(ApiConstants.aseguradoFoto(matricula));
      if (response is ApiSuccess && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawPhoto = data['foto2'] as String? ?? '';
        final cleanPhoto = AuthService.cleanBase64(rawPhoto);
        if (cleanPhoto.isNotEmpty) {
          UserSession.currentUser = UserSession.currentUser.copyWith(photoBase64: cleanPhoto);
          
          // Actualizar también en la lista de beneficiarios si está el titular
          final updatedBens = UserSession.currentUser.beneficiaries.map((b) {
            if (b.relationship == 'Titular') {
              return BeneficiaryModel(
                id: b.id,
                fullName: b.fullName,
                relationship: b.relationship,
                age: b.age,
                gender: b.gender,
                matricula: b.matricula,
                photoBase64: cleanPhoto,
              );
            }
            return b;
          }).toList();
          UserSession.currentUser = UserSession.currentUser.copyWith(beneficiaries: List<BeneficiaryModel>.from(updatedBens));

          // Persistir la foto actualizada
          await saveUserSession(UserSession.currentUser);
          if (kDebugMode) {
            debugPrint('📸 SessionRestore: foto titular actualizada en background');
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

  static Future<void> _tryRefreshBeneficiaryPhoto(BeneficiaryModel beneficiary) async {
    final api = ApiClient();
    try {
      final response = await api.get(ApiConstants.aseguradoFoto(beneficiary.matricula));
      if (response is ApiSuccess && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawPhoto = data['foto2'] as String? ?? '';
        final cleanPhoto = AuthService.cleanBase64(rawPhoto);
        if (cleanPhoto.isNotEmpty) {
          final updatedBens = UserSession.currentUser.beneficiaries.map((b) {
            if (b.id == beneficiary.id) {
              return BeneficiaryModel(
                id: b.id,
                fullName: b.fullName,
                relationship: b.relationship,
                age: b.age,
                gender: b.gender,
                matricula: b.matricula,
                photoBase64: cleanPhoto,
              );
            }
            return b;
          }).toList();
          
          UserSession.currentUser = UserSession.currentUser.copyWith(beneficiaries: List<BeneficiaryModel>.from(updatedBens));
          await saveUserSession(UserSession.currentUser);
          if (kDebugMode) {
            debugPrint('📸 SessionRestore: foto de beneficiario ${beneficiary.fullName} actualizada');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ SessionRestore: no se pudo actualizar foto de beneficiario: $e');
      }
    } finally {
      api.close();
    }
  }

  // ─── Obtener matrícula (para validación de token) ─────────────────────────

  /// Retorna la matrícula guardada sin restaurar toda la sesión.
  static Future<String?> getMatricula() async {
    try {
      final jsonStr = await _storage.read(key: _keyUserData);
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
    await _storage.delete(key: _keyUserData);
  }
}
