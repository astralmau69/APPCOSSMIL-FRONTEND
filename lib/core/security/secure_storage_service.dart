import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CAPA DE ALMACENAMIENTO SEGURO — Inversión de Dependencias
//
//  Por qué existe si ya hay TokenStorage y SessionRestoreService (estáticos):
//    - Los métodos estáticos no pueden ser mockeados en tests unitarios.
//    - Esta interfaz permite inyectar una implementación in-memory en tests
//      sin tocar el Keychain/Keystore real del dispositivo.
//    - AuthRepository y cualquier servicio futuro dependen de ISecureStorageService,
//      no de FlutterSecureStorage directamente (Open/Closed Principle).
//
//  Relación con el código existente:
//    - TokenStorage y SessionRestoreService continúan funcionando sin cambios;
//      son consumidores directos de FlutterSecureStorage para sus propias keys.
//    - SecureStorageServiceImpl comparte el mismo backend cifrado
//      (cossmil_secure_prefs) pero no interfiere con las keys existentes.
// ─────────────────────────────────────────────────────────────────────────────

/// Contrato de la capa de almacenamiento seguro cifrado.
///
/// Implementaciones:
///   - [SecureStorageServiceImpl] → producción (Keychain / EncryptedSharedPrefs)
///   - `InMemorySecureStorage` → tests unitarios (sin plataforma)
abstract interface class ISecureStorageService {
  /// Persiste [value] bajo [key] de forma cifrada en el hardware seguro.
  ///
  /// Si la clave ya existe, sobreescribe el valor anterior.
  Future<void> write({required String key, required String value});

  /// Lee el valor asociado a [key].
  ///
  /// Retorna `null` si la clave no existe o si ocurre un error de lectura.
  Future<String?> read({required String key});

  /// Elimina la entrada [key] del almacenamiento seguro.
  ///
  /// No lanza error si la clave no existe.
  Future<void> delete({required String key});

  /// Elimina TODAS las entradas del namespace seguro de la app.
  ///
  /// ⚠ Usar solo en escenarios extremos (reinstalación, test setup/teardown).
  /// En logout normal usar [delete] sobre keys específicas para no borrar
  /// el PIN/biometría del usuario.
  Future<void> deleteAll();

  /// Lee todas las entradas disponibles como mapa key→value.
  Future<Map<String, String>> readAll();

  /// Retorna `true` si existe una entrada para [key].
  Future<bool> containsKey({required String key});
}

// ─────────────────────────────────────────────────────────────────────────────
//  IMPLEMENTACIÓN DE PRODUCCIÓN
// ─────────────────────────────────────────────────────────────────────────────

/// Implementación de [ISecureStorageService] para producción.
///
/// Plataforma:
///   - **iOS / macOS**: Apple Keychain con `accessibility: first_unlock`.
///   - **Android**: `EncryptedSharedPreferences` (API 23+).
///   - **Windows / Linux**: libsecret / sistema de credenciales del SO.
///
/// Todas las claves comparten el namespace `cossmil_secure_prefs` para
/// mantenerse aisladas de otras aplicaciones en el dispositivo.
class SecureStorageServiceImpl implements ISecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageServiceImpl()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          sharedPreferencesName: 'cossmil_secure_prefs',
        ),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<bool> containsKey({required String key}) =>
      _storage.containsKey(key: key);
}

// ─────────────────────────────────────────────────────────────────────────────
//  IMPLEMENTACIÓN IN-MEMORY (para tests unitarios)
// ─────────────────────────────────────────────────────────────────────────────

/// Implementación de [ISecureStorageService] en memoria para tests unitarios.
///
/// No requiere plataforma (Keychain / Keystore) ni permisos del SO.
/// Crear una instancia fresca por test para evitar estado compartido.
///
/// Ejemplo de uso en tests:
/// ```dart
/// final storage = InMemorySecureStorage();
/// final repo = AuthRepositoryImpl(storage: storage);
/// ```
class InMemorySecureStorage implements ISecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<Map<String, String>> readAll() async => Map.unmodifiable(_store);

  @override
  Future<bool> containsKey({required String key}) async =>
      _store.containsKey(key);
}
