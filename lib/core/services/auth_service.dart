import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/auth_token_model.dart';
import '../models/user_model.dart';
import '../models/beneficiary_model.dart';
import '../mock/mock_user_data.dart';

/// Resultado del intento de login.
/// Separa el caso exitoso del error para que la UI lo maneje limpiamente.
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
/// Solo hace llamadas HTTP — sin lógica de UI ni estado.
class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Login con credenciales del usuario.
  /// Usa OAuth2 Password Grant con Basic Auth de la app.
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    // Mock: bypass HTTP cuando el backend no está disponible
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

        // Actualizar MockUserData con datos de API reales pero preservar email/phone simulados
        MockUserData.user = UserModel(
          id: tokenModel.idper.toString(),
          fullName: '${tokenModel.nom} ${tokenModel.pat} ${tokenModel.mat}'.trim(),
          rank: MockUserData.user.rank,
          matricula: tokenModel.matricula,
          bloodType: MockUserData.user.bloodType,
          age: tokenModel.edad,
          role: tokenModel.rol == 'ROLE_ASETIT' ? 'Titular' : tokenModel.rol,
          isEnabled: true,
          hasMedicalAppointment: MockUserData.user.hasMedicalAppointment,
          email: MockUserData.user.email, // Fallback
          phone: MockUserData.user.phone, // Fallback
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

        return AuthSuccess(tokenModel);
      }

      if (response.statusCode == 401) {
        return const AuthError('Usuario o contraseña incorrectos.');
      }

      return AuthError(
        'Error del servidor (${response.statusCode}). Intente más tarde.',
      );
    } on Exception catch (e) {
      return AuthError('No se pudo conectar al servidor: $e');
    }
  }
}
