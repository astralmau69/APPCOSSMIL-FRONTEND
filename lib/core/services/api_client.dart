import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// Cliente HTTP centralizado que inyecta automáticamente
/// el Bearer token en cada request protegido.
///
/// Uso:
/// ```dart
/// final client = ApiClient();
/// final response = await client.get('/api/programacion/regionales/1');
/// ```
class ApiClient {
  final http.Client _http;

  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  // ── GET con Bearer Token ──────────────────────────────────────────────

  /// Realiza un GET autenticado.
  /// Retorna el body como `Map<String, dynamic>` si es JSON.
  Future<ApiClientResponse> get(String path) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    final token = await TokenStorage.getToken();

    if (kDebugMode) {
      debugPrint('🌐 GET $url');
    }

    try {
      final response = await _http.get(url, headers: _headers(token));

      if (kDebugMode) {
        debugPrint('   ↳ ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiClientResponse.success(body);
      }

      if (response.statusCode == 401) {
        return const ApiClientResponse.error(
          'Sesión expirada. Inicie sesión nuevamente.',
          statusCode: 401,
        );
      }

      return ApiClientResponse.error(
        'Error del servidor (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('   ↳ ERROR: $e');
      }
      return ApiClientResponse.error(
        'No se pudo conectar al servidor.',
        statusCode: 0,
      );
    }
  }

  // ── Headers ───────────────────────────────────────────────────────────

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'insomnia/2023.5.8',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}

/// Respuesta genérica del [ApiClient].
sealed class ApiClientResponse {
  const ApiClientResponse();

  const factory ApiClientResponse.success(dynamic data) = ApiSuccess;
  const factory ApiClientResponse.error(String message, {int statusCode}) =
      ApiError;
}

class ApiSuccess extends ApiClientResponse {
  final dynamic data;
  const ApiSuccess(this.data);
}

class ApiError extends ApiClientResponse {
  final String message;
  final int statusCode;
  const ApiError(this.message, {this.statusCode = 0});
}
