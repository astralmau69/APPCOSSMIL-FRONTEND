import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../models/auth_token_model.dart';

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
        return AuthSuccess(AuthTokenModel.fromJson(json));
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
