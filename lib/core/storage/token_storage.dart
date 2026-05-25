import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/web_local_storage.dart';

/// Gestiona el token de acceso y refresh de forma segura en el dispositivo.
/// iOS: Keychain | Android: Keystore / EncryptedSharedPreferences | Web: localStorage
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
  );
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  /// Guarda ambos tokens tras un login exitoso.
  static Future<void> saveToken(String token) async {
    if (kIsWeb) { webLsSet(_keyAccessToken, token); return; }
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Guarda el refresh token.
  static Future<void> saveRefreshToken(String token) async {
    if (kIsWeb) { webLsSet(_keyRefreshToken, token); return; }
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Lee el access token guardado. Retorna null si no existe.
  static Future<String?> getToken() async {
    if (kIsWeb) return webLsGet(_keyAccessToken);
    return _storage.read(key: _keyAccessToken);
  }

  /// Lee el refresh token guardado. Retorna null si no existe.
  static Future<String?> getRefreshToken() async {
    if (kIsWeb) return webLsGet(_keyRefreshToken);
    return _storage.read(key: _keyRefreshToken);
  }

  /// Borra ambos tokens (logout).
  static Future<void> deleteToken() async {
    if (kIsWeb) {
      webLsDel(_keyAccessToken);
      webLsDel(_keyRefreshToken);
      return;
    }
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Borra TODO el almacenamiento seguro de la app.
  static Future<void> wipeAll() async {
    if (kIsWeb) { webLsClear(); return; }
    await _storage.deleteAll();
  }

  /// Verifica si el usuario tiene sesión activa.
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
