/// Configuración global de la app.
/// Cambiar [useMockData] a false cuando el backend esté disponible.
class AppConfig {
  static const bool useMockData = false;

  /// Versión declarada de la app — debe coincidir con pubspec.yaml.
  /// Se usa en el chequeo de versión para que no dependa del APK compilado.
  static const String appVersion = '1.0.2';
}
