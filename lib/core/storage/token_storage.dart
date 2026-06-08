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
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  /// Lee una clave con reintentos: tras reiniciar el dispositivo la primera
  /// lectura del Keystore puede fallar de forma transitoria. Evita que un
  /// fallo pasajero se interprete como "sin sesión" y fuerce un re-login.
  static Future<String?> _readResilient(String key, {int retries = 2}) async {
    for (int attempt = 0; ; attempt++) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        if (attempt >= retries) rethrow;
        await Future.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
  }

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
    return _readResilient(_keyAccessToken);
  }

  /// Lee el refresh token guardado. Retorna null si no existe.
  static Future<String?> getRefreshToken() async {
    if (kIsWeb) return webLsGet(_keyRefreshToken);
    return _readResilient(_keyRefreshToken);
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
