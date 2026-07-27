import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// Bloqueo de capturas y grabación de pantalla (Android `FLAG_SECURE`).
///
/// En pantallas sensibles (el carnet de asegurado) se activa al entrar y se
/// desactiva al salir. En plataformas que no lo soportan (iOS/web/escritorio)
/// las llamadas son no-op silenciosas.
class ScreenSecurityService {
  ScreenSecurityService._();

  static const MethodChannel _channel = MethodChannel(
    'cossmil.security/screenshot',
  );

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Impide capturas y grabación de pantalla mientras la pantalla esté visible.
  static Future<void> enable() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {
      // Sin canal nativo (build viejo): ignorar.
    }
  }

  /// Vuelve a permitir capturas al abandonar la pantalla sensible.
  static Future<void> disable() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }
}
