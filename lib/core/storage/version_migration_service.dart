import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Detecta cambios de versión del APK instalado.
///
/// Flujo:
///  splash → VersionMigrationService.runIfNeeded() →
///    si versión cambió → registra la nueva versión (sin borrar datos).
///    si es la misma versión → no hace nada.
///
/// La versión se lee automáticamente desde pubspec.yaml en tiempo de ejecución
/// con [PackageInfo]. No hay ningún string que actualizar manualmente.
class VersionMigrationService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
  );

  /// Clave donde se guarda la última versión ejecutada.
  static const _keyLastVersion = 'app_last_version';

  /// Verifica si la app fue actualizada y, de ser así, limpia todos los datos
  /// para que el usuario empiece desde cero (nuevo login, nuevo PIN).
  ///
  /// Retorna `true` si se ejecutó una migración (datos limpiados).
  static Future<bool> runIfNeeded() async {
    try {
      // Leer la versión actual desde el manifest/Info.plist del APK/IPA.
      final info = await PackageInfo.fromPlatform();
      // Combinamos name+build para detectar cualquier cambio de versión o build.
      final currentVersion = '${info.version}+${info.buildNumber}';

      final lastVersion = await _storage.read(key: _keyLastVersion);

      // Primera instalación o versión diferente → registrar sin borrar datos.
      // El usuario puede seguir usando su PIN/huella configurada.
      if (lastVersion == null || lastVersion != currentVersion) {
        await _storage.write(key: _keyLastVersion, value: currentVersion);
        return true; // versión nueva detectada
      }

      return false; // misma versión, sin cambios
    } catch (_) {
      // En caso de cualquier error de storage, continuar normalmente
      return false;
    }
  }

}
