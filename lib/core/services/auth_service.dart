import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/auth_token_model.dart';
import '../models/user_model.dart';
import '../models/beneficiary_model.dart';
import '../session/user_session.dart';
import 'api_client.dart';
import '../storage/token_storage.dart';
import 'security_service.dart';
import 'session_restore_service.dart';
import '../extensions/string_extensions.dart';
import '../utils/error_mapper.dart';

/// Resultado del intento de login.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  final AuthTokenModel token;
  const AuthSuccess(this.token);
}

enum AuthErrorType { wrongPassword, notFound, disabled, network, server, unknown }

class AuthError extends AuthResult {
  final String message;
  final AuthErrorType type;
  const AuthError(this.message, [this.type = AuthErrorType.unknown]);
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

      // ── DEBUG TEMPORAL: ver exactamente qué responde el servidor ──────────
      debugPrint('🌐 LOGIN HTTP ${response.statusCode}');
      debugPrint('   URL: ${ApiConstants.tokenUri}');
      debugPrint('   username: "$username" | password: "$password"');
      if (response.statusCode != 200) {
        debugPrint('   ❌ Body: ${utf8.decode(response.bodyBytes)}');
      }
      // ── FIN DEBUG ─────────────────────────────────────────────────────────

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final tokenModel = AuthTokenModel.fromJson(json);

        if (kDebugMode) {
          debugPrint('🔑 OAuth token parsed: edad=${tokenModel.edad}, genero="${tokenModel.genero}", idper=${tokenModel.idper}');
        }

        // Guardar tokens para que ApiClient pueda usarlos
        await TokenStorage.saveToken(tokenModel.accessToken);
        if (tokenModel.refreshToken.isNotEmpty) {
          await TokenStorage.saveRefreshToken(tokenModel.refreshToken);
        }

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

        // Mapear datos básicos a UserSession.currentUser
        final userRoleIsTitular = tokenModel.rol == 'ROLE_ASETIT';
        
        final selfAsFallback = BeneficiaryModel(
          id: tokenModel.idper.toString(),
          fullName: '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim().toDisplayCase,
          relationship: userRoleIsTitular ? 'Titular' : 'Beneficiario',
          age: tokenModel.edad,
          gender: tokenModel.genero,
          matricula: tokenModel.matricula.trim(),
          grado: tokenModel.grado.isNotEmpty ? tokenModel.grado : 'Asegurado',
        );

        final loggedUser = UserModel(
          id: tokenModel.idper.toString(),
          fullName: selfAsFallback.fullName,
          rank: tokenModel.grado.isNotEmpty ? tokenModel.grado : 'Asegurado',
          matricula: selfAsFallback.matricula,
          bloodType: tokenModel.bloodType,
          allergies: tokenModel.allergies,
          age: tokenModel.edad,
          gender: tokenModel.genero,
          role: userRoleIsTitular ? 'Titular' : tokenModel.rol,
          isEnabled: true,
          hasMedicalAppointment: false,
          email: tokenModel.correo.trim(),
          phone: tokenModel.numeroCelular.trim(),
          ci: tokenModel.ci,
          idseg: tokenModel.idseg,
          uc: tokenModel.uc,
          beneficiaries: rawBeneficiarios ?? [selfAsFallback],
        );

        // Si el login es del Titular, pero el grupo familiar obtenido no incluye al titular explícitamente, lo inyectamos:
        if (rawBeneficiarios != null && userRoleIsTitular && !rawBeneficiarios.any((b) => b.isTitular)) {
          loggedUser.beneficiaries.insert(0, selfAsFallback);
        }

        // Forzar que el Beneficiario Titular tome el grado militar (rank) del modelo principal 
        // si el endpoint de beneficiarios no lo trajo.
        final enforcedBeneficiaries = loggedUser.beneficiaries.map((b) {
          if (b.isTitular && b.grado.isEmpty) {
            return BeneficiaryModel(
              id: b.id,
              fullName: b.fullName,
              relationship: b.relationship,
              age: b.age,
              gender: b.gender,
              matricula: b.matricula,
              photoBase64: b.photoBase64,
              grado: loggedUser.rank,
              serviceStatus: b.serviceStatus,
            );
          }
          return b;
        }).toList();

        // Actualizar sesión global
        UserSession.currentUser = loggedUser.copyWith(beneficiaries: enforcedBeneficiaries);

        // Fallback global para que displayTitle siempre encuentre el rango del titular
        BeneficiaryModel.titularRankFallback = loggedUser.rank;

        debugPrint('✅ UserSession poblada: ${UserSession.currentUser.fullName}');
        debugPrint('👨‍👩‍👧‍👦 Beneficiarios en sesión: ${UserSession.currentUser.beneficiaries.length}');

        // Guardar nombre de usuario para la pantalla de desbloqueo local
        await SecurityService.saveDisplayName(
          '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim().toDisplayCase,
        );

        // Intentar cargar la foto jefe y luego la de sus familiares
        try {
          final extraData = await fetchProfileExtraData(tokenModel.matricula);
          String? titularPhoto;
          if (extraData != null) {
            titularPhoto = cleanBase64(extraData['foto2'] as String? ?? '');
            
            final eBloodType = (extraData['gruposan'] as String? ?? extraData['grupoSanguineo'] as String? ?? extraData['grupo_sanguineo'] as String? ?? '').trim();
            final eAllergies = (extraData['alergia'] as String? ?? extraData['alergias'] as String? ?? extraData['allergies'] as String? ?? '').trim();
            final eGrado = (extraData['grado']?.toString() ??
                            extraData['Grado']?.toString() ??
                            extraData['rango']?.toString() ??
                            extraData['Rango']?.toString() ?? '').trim();
            final eRefe4 = (extraData['refe4']?.toString() ?? '').trim();
            final eTelfemerg = (extraData['telfemerg'] as String? ?? '').trim();
            final eReferencia = (extraData['referencia'] as String? ?? '').trim();

            UserSession.currentUser = UserSession.currentUser.copyWith(
              photoBase64: titularPhoto,
              birthDate: extraData['fecnac'] as String? ?? '',
              bloodType: eBloodType.isNotEmpty ? eBloodType : UserSession.currentUser.bloodType,
              allergies: eAllergies.isNotEmpty ? eAllergies : UserSession.currentUser.allergies,
              rank: eGrado.isNotEmpty ? eGrado : UserSession.currentUser.rank,
              serviceStatus: eRefe4.isNotEmpty ? eRefe4 : UserSession.currentUser.serviceStatus,
              emergencyPhone: eTelfemerg.isNotEmpty ? eTelfemerg : UserSession.currentUser.emergencyPhone,
              referencia: eReferencia.isNotEmpty ? eReferencia : UserSession.currentUser.referencia,
            );

            // Actualizar fallback con el grado real del endpoint de foto
            BeneficiaryModel.titularRankFallback = UserSession.currentUser.rank;

            // Actualizar la foto y datos extra en la lista de beneficiarios para el titular
            final updatedBeneficiaries = UserSession.currentUser.beneficiaries.map((b) {
              if (b.isTitular) {
                return BeneficiaryModel(
                  id: b.id,
                  fullName: b.fullName,
                  relationship: b.relationship,
                  age: b.age,
                  gender: b.gender.isNotEmpty ? b.gender : tokenModel.genero,
                  matricula: b.matricula,
                  photoBase64: titularPhoto ?? '',
                  grado: eGrado.isNotEmpty ? eGrado : UserSession.currentUser.rank,
                  serviceStatus: eRefe4.isNotEmpty ? eRefe4 : UserSession.currentUser.serviceStatus,
                );
              }
              return b;
            }).toList();
            UserSession.currentUser = UserSession.currentUser.copyWith(beneficiaries: updatedBeneficiaries);
          }

          // Fetch paralelo de fotos de beneficiarios (máximo 4 para no saturar)
          final otherBeneficiaries = UserSession.currentUser.beneficiaries
              .where((b) => !b.isTitular && b.matricula.isNotEmpty)
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

            final finalBeneficiaries = UserSession.currentUser.beneficiaries.map((b) {
              final idx = otherBeneficiaries.indexWhere((ob) => ob.id == b.id);
              if (idx != -1 && results[idx] != null) {
                final data = results[idx]!;
                final photo = cleanBase64(data['foto2'] as String? ?? '');
                final bGrado = (data['grado'] as String? ?? '').trim();
                final bRefe4 = (data['refe4'] as String? ?? '').trim();
                if (kDebugMode && photo.isNotEmpty) {
                  debugPrint('   ✅ Foto obtenida para: ${otherBeneficiaries[idx].fullName}');
                }
                return BeneficiaryModel(
                  id: b.id,
                  fullName: b.fullName,
                  relationship: b.relationship,
                  age: b.age,
                  gender: b.gender,
                  matricula: b.matricula,
                  photoBase64: photo,
                  grado: bGrado,
                  serviceStatus: bRefe4,
                );
              }
              return b;
            }).toList();

            UserSession.currentUser = UserSession.currentUser.copyWith(beneficiaries: finalBeneficiaries);
          }
        } catch (e) {
          debugPrint('❌ Error cargando fotos de familia: $e');
        }

        // Re-guardar el displayName CON rango militar (el primer save fue antes de fetchProfileExtraData)
        await SecurityService.saveDisplayName(UserSession.currentUser.displayName);

        // Persistir sesión completa (nombre, fotos, matrícula, etc.)
        await SessionRestoreService.saveUserSession(UserSession.currentUser);

        return AuthSuccess(tokenModel);
      }

      if (response.statusCode >= 400 && response.statusCode < 500) {
        try {
          final errJson = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final desc = (errJson['error_description'] as String? ?? '').toLowerCase();
          if (desc.contains('disabled') || desc.contains('bloqueado') || desc.contains('locked') || desc.contains('inact')) {
            return const AuthError('Tu cuenta está inactiva o bloqueada. Comunícate con COSSMIL.', AuthErrorType.disabled);
          }
        } catch (_) {}
        return const AuthError('Ingrese sus credenciales correctos.\nVerifique su matrícula y contraseña.', AuthErrorType.wrongPassword);
      }

      if (response.statusCode >= 500) {
        // El servidor COSSMIL frecuentemente retorna 500 frente a errores de autenticación
        return const AuthError('Ingrese sus credenciales correctos.\nVerifique su matrícula y contraseña.', AuthErrorType.wrongPassword);
      }

      return const AuthError('Ingrese sus credenciales correctos.\nVerifique su matrícula y contraseña.', AuthErrorType.wrongPassword);
    } on SocketException {
      return const AuthError('Sin conexión a internet. Verifica tu red e inténtalo de nuevo.', AuthErrorType.network);
    } on TimeoutException {
      return const AuthError('La conexión tardó demasiado. Verifica tu red e inténtalo de nuevo.', AuthErrorType.network);
    } on Exception catch (e) {
      return AuthError(ErrorMapper.message(e, context: ErrorContext.login));
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

  /// Actualiza contraseña, correo y teléfono del usuario.
  /// Usado para el cambio obligatorio de contraseña en primer ingreso.
  Future<bool> updateUsuarioWeb({
    required int idper,
    required String password,
    required String email,
    required String phone,
    String? bloodType,
    String? allergies,
  }) async {
    final response = await _api.put(
      ApiConstants.updateUsuarioWeb(idper),
      body: {
        'pwd': password,
        'mail': email,
        'fon': phone,
        if (bloodType != null && bloodType.isNotEmpty) 'grupoSanguineo': bloodType,
        if (allergies != null && allergies.isNotEmpty) 'alergias': allergies,
        'sw': 1,
        'req_reset': true,
      },
    );

    return switch (response) {
      ApiSuccess() => true,
      ApiError(:final message) => throw Exception(message),
    };
  }

  /// Cambia solo la contraseña del usuario.
  Future<void> changePassword({
    required int idper,
    required String newPassword,
  }) async {
    final response = await _api.put(
      ApiConstants.changePassword(idper),
      body: {'pwd': newPassword},
    );
    switch (response) {
      case ApiSuccess():
        return;
      case ApiError(:final message):
        throw Exception(message);
    }
  }

  /// Actualiza el teléfono de emergencia y la referencia domiciliaria del afiliado.
  ///
  /// Endpoint: POST /api/safil/afiliado/actualiza-datosper
  /// [matricula] es la matrícula del usuario que realiza el cambio (campo usuariou).
  Future<void> actualizarDatosPer({
    required int idper,
    required String telfemerg,
    required String referencia,
    required String matricula,
  }) async {
    final response = await _api.post(
      ApiConstants.actualizaDatosPer(),
      body: {
        'idper': idper,
        'telfemerg': telfemerg,
        'referencia': referencia,
        'usuariou': matricula,
      },
    );
    switch (response) {
      case ApiSuccess():
        return;
      case ApiError(:final message):
        throw Exception(message);
    }
  }

  /// Actualiza correo y/o teléfono del usuario.
  Future<void> updateProfile({
    required int idper,
    required String mail,
    required String fon,
  }) async {
    final response = await _api.put(
      ApiConstants.updateProfile(idper),
      body: {'mail': mail, 'fon': fon},
    );
    switch (response) {
      case ApiSuccess():
        return;
      case ApiError(:final message):
        throw Exception(message);
    }
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
