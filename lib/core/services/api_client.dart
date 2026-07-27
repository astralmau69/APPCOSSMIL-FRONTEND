import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import '../utils/log_sanitizer.dart';

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

  /// Tiempo máximo de espera para cualquier petición
  static const Duration _globalTimeout = Duration(seconds: 15);

  /// Número máximo de intentos antes de fallar
  static const int _maxRetries = 3;

  /// Envoltorio para reintentar peticiones en caso de microcortes de red.
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await action();
      } catch (e) {
        final bool isNetworkError =
            e is SocketException ||
            e is TimeoutException ||
            e is http.ClientException;
        if (isNetworkError && attempts < _maxRetries) {
          if (kDebugMode) {
            debugPrint(
              '   ⚠ Fallo de red detectado ($e). Reintento $attempts de $_maxRetries en 1.5s...',
            );
          }
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        rethrow;
      }
    }
  }

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
      debugPrint(LogSanitizer.scrub('🌐 GET $url'));
    }

    try {
      return await _withRetry(() async {
        final response = await _http
            .get(url, headers: _headers(token))
            .timeout(_globalTimeout);

        if (kDebugMode) {
          debugPrint('   ↳ ${response.statusCode}');
        }

        if (response.statusCode == 200) {
          final body = jsonDecode(utf8.decode(response.bodyBytes));
          return ApiClientResponse.success(body);
        }

        if (response.statusCode == 401) {
          if (kDebugMode) {
            debugPrint(
              '   ↳ 401 UNAUTHORIZED: Token might be invalid or expired.',
            );
          }
          return const ApiClientResponse.error(
            'Sesión expirada. Inicie sesión nuevamente.',
            statusCode: 401,
          );
        }

        if (response.statusCode >= 500) {
          // Lanzar excepción para que el sistema de retries lo intente de nuevo
          throw SocketException('Error del servidor ${response.statusCode}');
        }

        return ApiClientResponse.error(
          'Error del servidor (${response.statusCode})',
          statusCode: response.statusCode,
        );
      });
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(LogSanitizer.scrub('   ↳ ERROR final: $e'));
      }
      return const ApiClientResponse.error(
        'No se pudo conectar al servidor.',
        statusCode: 0,
      );
    }
  }

  // ── POST con Bearer Token ─────────────────────────────────────────

  /// Realiza un POST autenticado con body JSON.
  /// Si recibe 401, intenta refresh_token y reintenta una vez.
  Future<ApiClientResponse> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final result = await _doPost(path, body: body);

    if (result is ApiError && result.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        if (kDebugMode)
          debugPrint('🔄 Token renovado, reintentando POST $path');
        return _doPost(path, body: body);
      }
    }

    return result;
  }

  /// POST interno sin lógica de retry.
  Future<ApiClientResponse> _doPost(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    final token = await TokenStorage.getToken();

    if (kDebugMode) {
      debugPrint(LogSanitizer.scrub('🌐 POST $url'));
      // Body NO se registra por seguridad (puede contener datos sensibles).
    }

    try {
      return await _withRetry(() async {
        final response = await _http
            .post(
              url,
              headers: _headers(token),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_globalTimeout);

        if (kDebugMode) {
          debugPrint('   ↳ ${response.statusCode}');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          return ApiClientResponse.success(decoded);
        }

        if (response.statusCode == 401) {
          return const ApiClientResponse.error(
            'Sesión expirada. Inicie sesión nuevamente.',
            statusCode: 401,
          );
        }

        if (response.statusCode >= 500) {
          throw SocketException('Error del servidor ${response.statusCode}');
        }

        return ApiClientResponse.error(
          'Error del servidor (${response.statusCode})',
          statusCode: response.statusCode,
        );
      });
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(LogSanitizer.scrub('   ↳ ERROR final: $e'));
      }
      return const ApiClientResponse.error(
        'No se pudo conectar al servidor.',
        statusCode: 0,
      );
    }
  }

  // ── PUT con Bearer Token ──────────────────────────────────────────

  /// Realiza un PUT autenticado con body JSON.
  /// Si recibe 401, intenta refresh_token y reintenta una vez.
  Future<ApiClientResponse> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final result = await _doPut(path, body: body);

    if (result is ApiError && result.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        if (kDebugMode) debugPrint('🔄 Token renovado, reintentando PUT $path');
        return _doPut(path, body: body);
      }
    }

    return result;
  }

  /// PUT interno sin lógica de retry.
  Future<ApiClientResponse> _doPut(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$path');
    final token = await TokenStorage.getToken();

    if (kDebugMode) {
      debugPrint(LogSanitizer.scrub('🌐 PUT $url'));
      // Body NO se registra por seguridad (puede contener la contraseña, etc.).
    }

    try {
      return await _withRetry(() async {
        final response = await _http
            .put(
              url,
              headers: _headers(token),
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(_globalTimeout);

        if (kDebugMode) {
          debugPrint('   ↳ ${response.statusCode}');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          final bodyStr = utf8.decode(response.bodyBytes);
          try {
            return ApiClientResponse.success(jsonDecode(bodyStr));
          } on FormatException {
            // La API retornó texto plano en lugar de JSON.
            if (kDebugMode) {
              debugPrint(
                LogSanitizer.scrub(
                  '   ↳ Respuesta en texto plano: "${bodyStr.trim()}"',
                ),
              );
            }
            return ApiClientResponse.success(bodyStr.trim());
          }
        }

        if (response.statusCode == 401) {
          return const ApiClientResponse.error(
            'Sesión expirada. Inicie sesión nuevamente.',
            statusCode: 401,
          );
        }

        if (response.statusCode >= 500) {
          throw SocketException('Error del servidor ${response.statusCode}');
        }

        return ApiClientResponse.error(
          'Error del servidor (${response.statusCode})',
          statusCode: response.statusCode,
        );
      });
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint(LogSanitizer.scrub('   ↳ ERROR final: $e'));
      }
      return const ApiClientResponse.error(
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

    if (kDebugMode) debugPrint(LogSanitizer.scrub('🌐 GET (bytes) $url'));

    try {
      return await _withRetry(() async {
        final response = await _http
            .get(url, headers: _headers(token))
            .timeout(_globalTimeout);

        if (response.statusCode == 200) {
          return response.bodyBytes;
        }

        // Si 401, intentar refresh y reintentar
        if (response.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed) {
            final retry = await _http
                .get(url, headers: _headers(await TokenStorage.getToken()))
                .timeout(_globalTimeout);
            if (retry.statusCode == 200) return retry.bodyBytes;
          }
        }

        if (response.statusCode >= 500) {
          throw SocketException('Error del servidor ${response.statusCode}');
        }

        if (kDebugMode)
          debugPrint('   ↳ Error descargando bytes: ${response.statusCode}');
        return null;
      });
    } on Exception catch (e) {
      if (kDebugMode) debugPrint(LogSanitizer.scrub('   ↳ ERROR getBytes: $e'));
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
      debugPrint('🔄 Intentando refresh token (silencioso)...');
    }

    // Renovación SILENCIOSA: el 401 ocurre en pleno interceptor de red, así que
    // NO se pide biometría aquí — lanzar un prompt sorpresa mientras el usuario
    // lee o escribe es disruptivo. La biometría se mantiene estricta donde sí
    // corresponde: App Resume (TabShell) y acciones críticas. Renovar el JWT con
    // el refresh_token YA almacenado de forma segura es invisible para el usuario.
    try {
      final response = await _http
          .post(
            ApiConstants.tokenUri,
            headers: {
              'Authorization': ApiConstants.basicAuthHeader,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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

      // Si el backend rechaza el refresh_token solo borramos los tokens del servidor.
      // El PIN y la biometría son locales y NO dependen del ciclo de vida del token:
      // el usuario conserva su desbloqueo configurado para la próxima sesión.
      await TokenStorage.deleteToken();
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
