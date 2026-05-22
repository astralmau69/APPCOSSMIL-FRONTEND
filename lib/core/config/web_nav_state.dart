import 'package:flutter/foundation.dart';

/// Puente de comunicación entre el shell web (app.dart) y TabShell.
/// Solo activo cuando kIsWeb == true.
class WebNavState {
  WebNavState._();

  /// true cuando el layout de escritorio con barra lateral está activo (≥1100px).
  /// TabShell lo lee en build() para decidir si mostrar el FloatingNavBar.
  static bool sidebarActive = false;

  /// Índice de la pestaña activa. TabShell lo actualiza; el sidebar lo escucha.
  static final tabIndex = ValueNotifier<int>(0);

  /// Callback registrado por TabShell para cambiar de pestaña.
  static void Function(int)? _switchTab;

  static void register(void Function(int) fn) => _switchTab = fn;
  static void unregister() => _switchTab = null;

  /// Llamado desde el sidebar de escritorio para cambiar la pestaña activa.
  static void switchTo(int index) => _switchTab?.call(index);
}
