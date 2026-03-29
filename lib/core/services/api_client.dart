import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// Cliente HTTP centralizado que inyecta automáticamente
/// el Bearer token en cada request protegido.
///
/// Si recibe un 401, intenta renovar el token usando el refresh_token
/// y reintenta la petición original una vez.
class ApiClient {
  final http.Client _http;

  /// Evita múltiples refresh simultáneos.
  static Future<bool>? _refreshInProgress;

  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Cierra el cliente HTTP. Llamar cuando ya no se necesite.
  void close() => _http.close();

  // ── GET con Bearer Token ──────────────────────────────────────────────

  /// Realiza un GET autenticado.
  /// Si recibe 401, intenta refresh_token y reintenta una vez.
  Future<ApiClientResponse> get(String path) async {
    final result = await _doGet(path);

    // Si es 401, intentar refresh y reintentar
    if (result is ApiError && result.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        if (kDebugMode) debugPrint('🔄 Token renovado, reintentando GET $path');
        return _doGet(path);
      }
    }

    return result;
  }

  /// GET interno sin lógica de retry.
  Future<ApiClientResponse> _doGet(String path) async {
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
        if (kDebugMode) {
          debugPrint('   ↳ 401 UNAUTHORIZED: Token might be invalid or expired.');
        }
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

  // ── POST con Bearer Token ─────────────────────────────────────────

  /// Realiza un POST autenticado con body JSON.
  /// Si recibe 401, intenta refresh_token y reintenta una vez.
  Future<ApiClientResponse> post(String path, {Map<String, dynamic>? body}) async {
    final result = await _doPost(path, body: body);

    if (result is ApiError && result.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        if (kDebugMode) debugPrint('🔄 Token renovado, reintentando POST $path');
        return _doPost(path, body: body);
      }
    }

    return result;
  }

  /// POST interno sin lógica de retry.
  Future<ApiClientResponse> _doPost(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    final token = await TokenStorage.getToken();

    if (kDebugMode) {
      debugPrint('🌐 POST $url');
      debugPrint('   📤 body: $body');
    }

    try {
      final response = await _http.post(
        url,
        headers: _headers(token),
        body: body != null ? jsonEncode(body) : null,
      );

      if (kDebugMode) {
        debugPrint('   ↳ ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return ApiClientResponse.success(decoded);
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

  // ── GET Raw Bytes (para PDFs) ──────────────────────────────────────

  /// Descarga bytes crudos (PDF, imágenes, etc.) con Bearer token.
  Future<Uint8List?> getBytes(String path) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    final token = await TokenStorage.getToken();

    if (kDebugMode) debugPrint('🌐 GET (bytes) $url');

    try {
      final response = await _http.get(url, headers: _headers(token));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      // Si 401, intentar refresh y reintentar
      if (response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retry = await _http.get(url, headers: _headers(await TokenStorage.getToken()));
          if (retry.statusCode == 200) return retry.bodyBytes;
        }
      }

      if (kDebugMode) debugPrint('   ↳ Error descargando bytes: ${response.statusCode}');
      return null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('   ↳ ERROR getBytes: $e');
      return null;
    }
  }

  // ── Token Refresh ───────────────────────────────────────────────────

  /// Intenta renovar el access_token usando el refresh_token.
  /// Retorna true si tuvo éxito.
  Future<bool> _tryRefreshToken() async {
    // Si ya hay un refresh en progreso, esperar ese resultado
    if (_refreshInProgress != null) {
      return _refreshInProgress!;
    }

    _refreshInProgress = _doRefreshToken();
    try {
      return await _refreshInProgress!;
    } finally {
      _refreshInProgress = null;
    }
  }

  Future<bool> _doRefreshToken() async {
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      if (kDebugMode) debugPrint('   ⚠ No refresh_token disponible.');
      return false;
    }

    if (kDebugMode) {
      debugPrint('🔄 Intentando refresh token...');
    }

    try {
      final response = await _http.post(
        ApiConstants.tokenUri,
        headers: {
          'Authorization': ApiConstants.basicAuthHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = (json['access_token'] as String? ?? '').trim();
        final newRefreshToken = (json['refresh_token'] as String? ?? '').trim();

        if (newAccessToken.isNotEmpty) {
          await TokenStorage.saveToken(newAccessToken);
          if (newRefreshToken.isNotEmpty) {
            await TokenStorage.saveRefreshToken(newRefreshToken);
          }
          if (kDebugMode) {
            debugPrint('   ✅ Token renovado exitosamente.');
          }
          return true;
        }
      }

      if (kDebugMode) {
        debugPrint('   ❌ Refresh falló: ${response.statusCode}');
      }
      return false;
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('   ❌ Refresh error: $e');
      }
      return false;
    }
  }

  // ── Headers ───────────────────────────────────────────────────────────

  Map<String, String> _headers(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else if (kDebugMode) {
      debugPrint('   ⚠ WARNING: Attempting protected request without token.');
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
