import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gestiona el token de acceso y refresh de forma segura en el dispositivo.
/// iOS: Keychain | Android: Keystore / EncryptedSharedPreferences
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
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Guarda el refresh token.
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Lee el access token guardado. Retorna null si no existe.
  static Future<String?> getToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  /// Lee el refresh token guardado. Retorna null si no existe.
  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  /// Borra ambos tokens (logout).
  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Borra TODO el almacenamiento seguro de la app.
  /// Usar al cerrar sesión para garantizar que no queden datos residuales.
  /// Esto también evita que los datos persistan si el usuario desinstala y reinstala.
  static Future<void> wipeAll() async {
    await _storage.deleteAll();
  }

  /// Verifica si el usuario tiene sesión activa.
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
