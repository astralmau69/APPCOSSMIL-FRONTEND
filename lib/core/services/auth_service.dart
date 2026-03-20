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
          beneficiaries: MockUserData.user.beneficiaries.map((b) {
            if (b.relationship == 'Titular') {
              return BeneficiaryModel(
                id: tokenModel.idper.toString(),
                fullName: '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim(),
                relationship: 'Titular',
                age: tokenModel.edad,
              );
            }
            return b;
          }).toList(),
        );

        // Intentar cargar la foto y fecha de nacimiento (Extra Data)
        try {
          final extraData = await fetchProfileExtraData(tokenModel.matricula);
          if (extraData != null) {
            MockUserData.user = MockUserData.user.copyWith(
              photoBase64: extraData['foto2'] as String? ?? '',
              birthDate: extraData['fecnac'] as String? ?? '',
            );
          }
        } catch (e) {
          debugPrint('Error cargando foto/perfil extra: $e');
        }

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
  Future<Map<String, dynamic>?> fetchProfileExtraData(String matricula) async {
    if (AppConfig.useMockData) return null;

    final response = await _api.get(ApiConstants.aseguradoFoto(matricula));
    if (response is ApiSuccess) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }
}
