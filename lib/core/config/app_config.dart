/// Configuración global de la app.
/// Cambiar [useMockData] a false cuando el backend esté disponible.
class AppConfig {
  static const bool useMockData = false;

  /// Carnet digital de asegurado (QR rotativo, validador, exportación PDF).
  /// OCULTO hasta recibir autorización oficial de COSSMIL para publicarlo.
  /// Para reactivarlo: cambiar a `true` (vuelve a aparecer el acceso en Inicio).
  static const bool carnetDigitalEnabled = false;

  /// Versión declarada de la app — debe coincidir con pubspec.yaml.
  /// Se usa en el chequeo de versión para que no dependa del APK compilado.
  static const String appVersion = '1.0.3';

  /// IDs de sucursal habilitados para reserva y calendario.
  ///   '1'  → Hospital Militar Central N° 1 - La Paz       (HMC-LPZ)
  ///   '2'  → Hospital Militar N° 3 - Cochabamba           (REG-CBBA)
  ///   '3'  → Hospital Militar N° 3 - Santa Cruz           (REG-SCZ)
  ///   '11' → Hospital Militar - Tarija                    (REG-TJ)
  ///
  /// Mantener sincronizado con la lista habilitada del backend. Centralizado
  /// aquí (en vez de hardcoded por pantalla) para que agregar/retirar un
  /// hospital sea un cambio en un solo punto del cliente.
  static const Set<String> allowedHospitalIds = {'1', '2', '3', '11'};
}
