import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gestiona el token de acceso de forma segura en el dispositivo.
/// iOS: Keychain | Android: Keystore / EncryptedSharedPreferences
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyAccessToken = 'access_token';

  /// Guarda el token tras un login exitoso.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  /// Lee el token guardado. Retorna null si no existe.
  static Future<String?> getToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  /// Borra el token (logout).
  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyAccessToken);
  }

  /// Verifica si el usuario tiene sesión activa.
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
