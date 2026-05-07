import 'package:package_info_plus/package_info_plus.dart';

/// Proveedor centralizado de la versión de la app.
///
/// Usa [PackageInfo] (fuente de verdad del APK/IPA) con un fallback
/// al valor hardcoded en caso de error o en tests.
///
/// ### Uso
/// ```dart
/// final version = await AppVersionHelper.getVersion();
/// // → '1.0.3' o '1.0.3+5' (según pubspec)
/// ```
class AppVersionHelper {
  AppVersionHelper._();

  static String? _cached;

  /// Fallback hardcoded para pruebas unitarias o si PackageInfo falla.
  static const String fallback = '1.0.3';

  /// Retorna la versión del paquete (e.g., "1.0.3").
  /// Almacena en caché tras la primera lectura.
  static Future<String> getVersion() async {
    if (_cached != null) return _cached!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cached = info.version.isNotEmpty ? info.version : fallback;
    } catch (_) {
      _cached = fallback;
    }
    return _cached!;
  }

  /// Versión sincrónica — devuelve el valor cacheado o [fallback].
  /// Útil en widgets que ya cargaron la versión previamente.
  static String get versionSync => _cached ?? fallback;

  /// Limpia el caché (útil en tests).
  static void clearCache() => _cached = null;
}
