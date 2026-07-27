import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:screen_protector/screen_protector.dart';

import '../utils/app_logger.dart';

/// Protección de pantalla para datos de salud (PHI): bloquea capturas y graba-
/// ción, y oscurece la app en la vista de "Aplicaciones recientes".
///
/// - Android: `FLAG_SECURE` (bloquea screenshots/screen-record y difumina la
///   miniatura de recientes).
/// - iOS: bloqueo de captura + capa de desenfoque al pasar a segundo plano.
///
/// Envuelve el paquete `screen_protector` detrás de una fachada propia para que
/// cambiarlo sea un cambio de UN archivo. [enable]/[disable] son idempotentes y
/// nunca lanzan: si el canal nativo no está disponible (p. ej. en web o un test)
/// se registra y se sigue.
///
/// Ciclo de vida: [enable] al entrar a la zona autenticada (post-login y en el
/// arranque de [TabShell], que cubre también el desbloqueo por PIN y la
/// restauración de sesión); [disable] en el logout.
class ScreenSecurity {
  ScreenSecurity._();

  static bool _active = false;

  /// true si la protección está activa.
  static bool get isActive => _active;

  /// Activa FLAG_SECURE + desenfoque en recientes. Idempotente.
  static Future<void> enable() async {
    if (_active || kIsWeb) return;
    _active = true;
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageWithBlur();
      AppLogger.info('ScreenSecurity', 'Protección de pantalla ACTIVADA');
    } catch (e) {
      _active = false; // no quedó activa realmente
      AppLogger.warn('ScreenSecurity', 'No se pudo activar la protección', e);
    }
  }

  /// Desactiva la protección (al cerrar sesión). Idempotente.
  static Future<void> disable() async {
    if (!_active || kIsWeb) return;
    _active = false;
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageWithBlurOff();
      AppLogger.info('ScreenSecurity', 'Protección de pantalla DESACTIVADA');
    } catch (e) {
      AppLogger.warn(
        'ScreenSecurity',
        'No se pudo desactivar la protección',
        e,
      );
    }
  }
}
