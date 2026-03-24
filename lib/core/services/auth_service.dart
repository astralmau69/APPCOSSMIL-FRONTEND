import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/auth_token_model.dart';
import '../models/user_model.dart';
import '../models/beneficiary_model.dart';
import '../mock/mock_user_data.dart';
import 'api_client.dart';
import '../storage/token_storage.dart';
import 'security_service.dart';
import 'session_restore_service.dart';

/// Resultado del intento de login.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  final AuthTokenModel token;
  const AuthSuccess(this.token);
}

class AuthError extends AuthResult {
  final String message;
  const AuthError(this.message);
}

/// Servicio de autenticación.
class AuthService {
  final http.Client _client;
  final ApiClient _api;

  AuthService({http.Client? client, ApiClient? api}) 
      : _client = client ?? http.Client(),
        _api = api ?? ApiClient();

  /// Login con credenciales del usuario.
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      await Future.delayed(const Duration(milliseconds: 800));
      return AuthSuccess(AuthTokenModel(
        accessToken: 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
        tokenType: 'bearer',
        expiresIn: 3600,
        scope: 'read write',
        jti: 'mock-jti',
      ));
    }

    try {
      final response = await _client.post(
        ApiConstants.tokenUri,
        headers: {
          'Authorization': ApiConstants.basicAuthHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'insomnia/2023.5.8',
        },
        body: {
          'grant_type': 'password',
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final tokenModel = AuthTokenModel.fromJson(json);

        // Guardar token primero para que ApiClient pueda usarlo
        await TokenStorage.saveToken(tokenModel.accessToken);

        // Extraer beneficiarios reales del JSON si existen
        final rawBeneficiarios = (json['beneficiarios'] as List<dynamic>?)
            ?.map((e) => BeneficiaryModel.fromJson(e as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          debugPrint('👨‍👩‍👧‍👦 Beneficiarios encontrados en JSON: ${rawBeneficiarios?.length ?? 0}');
          if (rawBeneficiarios != null) {
            for (var b in rawBeneficiarios) {
              debugPrint('   - ${b.fullName} (${b.relationship}) | Mat: "${b.matricula}" | Photo: ${b.photoBase64.isNotEmpty}');
            }
          }
        }

        // Mapear datos básicos a MockUserData.user
        MockUserData.user = UserModel(
          id: tokenModel.idper.toString(),
          fullName: '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim(),
          rank: tokenModel.grado.isNotEmpty ? tokenModel.grado : MockUserData.user.rank,
          matricula: tokenModel.matricula.trim(),
          bloodType: MockUserData.user.bloodType,
          age: tokenModel.edad,
          role: tokenModel.rol == 'ROLE_ASETIT' ? 'Titular' : tokenModel.rol,
          isEnabled: true,
          hasMedicalAppointment: MockUserData.user.hasMedicalAppointment,
          email: tokenModel.correo.isNotEmpty ? tokenModel.correo : MockUserData.user.email,
          phone: tokenModel.numeroCelular.isNotEmpty ? tokenModel.numeroCelular : MockUserData.user.phone,
          ci: tokenModel.ci,
          beneficiaries: rawBeneficiarios ?? MockUserData.user.beneficiaries.map((b) {
            if (b.relationship == 'Titular') {
              return BeneficiaryModel(
                id: tokenModel.idper.toString(),
                fullName: '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim(),
                relationship: 'Titular',
                age: tokenModel.edad,
                matricula: tokenModel.matricula.trim(),
              );
            }
            return b;
          }).toList(),
        );

        // Guardar nombre de usuario para la pantalla de desbloqueo local
        await SecurityService.saveDisplayName(
          '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim(),
        );

        // Intentar cargar la foto jefe y luego la de sus familiares
        try {
          final extraData = await fetchProfileExtraData(tokenModel.matricula);
          String? titularPhoto;
          if (extraData != null) {
            titularPhoto = cleanBase64(extraData['foto2'] as String? ?? '');
            MockUserData.user = MockUserData.user.copyWith(
              photoBase64: titularPhoto,
              birthDate: extraData['fecnac'] as String? ?? '',
            );

            // Actualizar la foto en la lista de beneficiarios para el titular
            final updatedBeneficiaries = MockUserData.user.beneficiaries.map((b) {
              if (b.relationship == 'Titular') {
                return BeneficiaryModel(
                  id: b.id,
                  fullName: b.fullName,
                  relationship: b.relationship,
                  age: b.age,
                  matricula: b.matricula,
                  photoBase64: titularPhoto ?? '',
                );
              }
              return b;
            }).toList();
            MockUserData.user = MockUserData.user.copyWith(beneficiaries: updatedBeneficiaries);
          }

          // Fetch paralelo de fotos de beneficiarios (máximo 4 para no saturar)
          final otherBeneficiaries = MockUserData.user.beneficiaries
              .where((b) => b.relationship != 'Titular' && b.matricula.isNotEmpty)
              .take(4)
              .toList();

          if (otherBeneficiaries.isNotEmpty) {
            if (kDebugMode) {
              debugPrint('📸 Fetching fotos para ${otherBeneficiaries.length} familiares...');
            }
            final photoFutures = otherBeneficiaries.map(
              (b) => fetchProfileExtraData(b.matricula)
                  .timeout(const Duration(seconds: 10), onTimeout: () => null),
            );
            final results = await Future.wait(photoFutures);

            final finalBeneficiaries = MockUserData.user.beneficiaries.map((b) {
              final idx = otherBeneficiaries.indexWhere((ob) => ob.id == b.id);
              if (idx != -1 && results[idx] != null) {
                final photo = cleanBase64(results[idx]!['foto2'] as String? ?? '');
                if (kDebugMode && photo.isNotEmpty) {
                  debugPrint('   ✅ Foto obtenida para: ${otherBeneficiaries[idx].fullName}');
                }
                return BeneficiaryModel(
                  id: b.id,
                  fullName: b.fullName,
                  relationship: b.relationship,
                  age: b.age,
                  matricula: b.matricula,
                  photoBase64: photo,
                );
              }
              return b;
            }).toList();

            MockUserData.user = MockUserData.user.copyWith(beneficiaries: finalBeneficiaries);
          }
        } catch (e) {
          debugPrint('❌ Error cargando fotos de familia: $e');
        }

        // Persistir sesión completa (nombre, fotos, matrícula, etc.)
        await SessionRestoreService.saveUserSession(MockUserData.user);

        return AuthSuccess(tokenModel);
      }

      if (response.statusCode == 401) {
        return const AuthError('Usuario o contraseña incorrectos.');
      }

      return AuthError('Error del servidor (${response.statusCode}).');
    } on Exception catch (e) {
      return AuthError('No se pudo conectar al servidor: $e');
    }
  }

  /// Recupera foto y fecha de nacimiento desde el endpoint de Safil.
  ///
  /// El endpoint puede retornar:
  ///   - Un [Map] directamente: `{"matricula":"...", "foto2":"..."}`
  ///   - Una [List] con un solo elemento: `[{"matricula":"...", "foto2":"..."}]`
  /// Esta función maneja ambos casos.
  Future<Map<String, dynamic>?> fetchProfileExtraData(String matricula) async {
    if (AppConfig.useMockData) return null;

    // Normalizar matrícula (puede venir con espacios al final)
    final cleanMat = matricula.trim();
    if (cleanMat.isEmpty) return null;

    if (kDebugMode) {
      debugPrint('📸 Fetching foto para matrícula: "$cleanMat"');
    }

    final response = await _api.get(ApiConstants.aseguradoFoto(cleanMat));

    if (response is ApiSuccess) {
      final data = response.data;

      if (kDebugMode) {
        debugPrint('📸 Response type: ${data.runtimeType}');
      }

      // Caso 1: la API retorna un Map directo
      if (data is Map<String, dynamic>) {
        return data;
      }

      // Caso 2: la API retorna una List (tomar el primer elemento)
      if (data is List && data.isNotEmpty) {
        final first = data[0];
        if (first is Map<String, dynamic>) {
          return first;
        }
      }

      if (kDebugMode) {
        debugPrint('⚠️ Response format inesperado: ${data.runtimeType}');
      }
    } else if (response is ApiError) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching foto: ${response.message} (${response.statusCode})');
      }
    }

    return null;
  }

  /// Limpia un string base64 que puede contener:
  ///   - Prefijo data URI (`data:image/jpeg;base64,`)
  ///   - Espacios, newlines, tabs
  /// Retorna solo los caracteres base64 válidos, o vacío si inválido.
  static String cleanBase64(String raw) {
    if (raw.isEmpty) return '';

    String cleaned = raw;

    // Quitar prefijo data URI si existe
    final commaIdx = cleaned.indexOf(',');
    if (commaIdx != -1 && cleaned.substring(0, commaIdx).contains('base64')) {
      cleaned = cleaned.substring(commaIdx + 1);
    }

    // Quitar whitespace (espacios, newlines, tabs, CR)
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');

    // Validar que queden caracteres base64 válidos
    if (cleaned.isEmpty || !RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleaned)) {
      return '';
    }

    return cleaned;
  }
}
