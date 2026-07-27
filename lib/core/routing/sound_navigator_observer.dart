import 'package:flutter/widgets.dart';

import '../constants/app_sounds.dart';
import '../theme/sound_manager.dart';

/// Sonoriza el "volver atrás" de TODA la app desde un único sitio.
///
/// El retroceso llega por muchas vías —la flecha de la barra, el botón físico
/// de Android, el gesto de arrastrar desde el borde en iOS, un
/// `Navigator.pop` en código— y todas terminan en el mismo evento del
/// navegador. Observarlo aquí evita repetir la llamada en decenas de
/// pantallas y garantiza que ninguna se quede sin sonido.
///
/// Solo suenan las [PageRoute] (pantallas). Los diálogos y hojas modales son
/// [PopupRoute] y quedan fuera a propósito: su apertura ya sonó y cerrarlos no
/// es "ir atrás".
///
/// Un [NavigatorObserver] solo puede estar acoplado a UN navegador, así que
/// cada navegador (el raíz y el de cada pestaña) necesita su propia instancia,
/// creada una sola vez y no en cada `build`.
class SoundNavigatorObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute) {
      // El antirrebote de SoundManager colapsa las ráfagas: un `popUntil`
      // que cierra varias pantallas suena una sola vez, como corresponde a
      // un único gesto.
      SoundManager.playUi(AppSounds.back, volume: 0.5);
    }
  }
}
