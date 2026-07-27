/// Catálogo de sonidos de interfaz de la app.
///
/// Toda la familia se genera con `tools/generate_ui_sounds.py` (sintetizador
/// propio, sin librerías ni descargas) y está afinada sobre la pentatónica de
/// La mayor, así cada sonido pertenece audiblemente al mismo sistema. Los
/// niveles ya vienen balanceados ENTRE archivos: el `volume` de
/// [SoundManager.playUi] escala la familia entera, no hay que ajustar cada
/// sonido por separado.
///
/// Formatos mezclados a propósito: los sonidos cortos de interacción van en
/// WAV (sin retardo de decodificador, que es justo donde se percibe la
/// latencia) y los largos en MP3 (pesan ~10× menos y nadie nota unos ms).
///
/// Criterio de uso: el sonido acompaña al háptico en acciones que el usuario
/// inicia, y marca resultados que importan. Nunca suena algo en cada scroll o
/// en cada tarjeta de una lista — una app profesional es discreta.
class AppSounds {
  AppSounds._();

  static const _base = 'sounds/';

  /// Pulsación de un botón de acción principal. Casi subliminal: sostiene al
  /// háptico, no compite con él.
  static const tap = '${_base}ui_tap.wav';

  /// Cambio de pestaña en la barra de navegación.
  static const nav = '${_base}ui_nav.wav';

  /// Avance dentro de un flujo de varios pasos (ej. la reserva de cita).
  static const select = '${_base}ui_select.wav';

  /// Volver atrás: las mismas notas de [select] en orden inverso. Lo dispara
  /// `SoundNavigatorObserver` para toda la app (flecha, botón físico, gesto de
  /// borde) — no hace falta llamarlo pantalla por pantalla.
  static const back = '${_base}ui_back.wav';

  /// Interruptores (tema claro/oscuro, preferencias).
  static const toggleOn = '${_base}ui_toggle_on.wav';
  static const toggleOff = '${_base}ui_toggle_off.wav';

  /// Apertura de un diálogo o una hoja modal.
  static const sheet = '${_base}ui_sheet.mp3';

  /// La instructora del tutorial aparece o suelta una burbuja.
  static const coach = '${_base}ui_coach.mp3';

  /// Avance de paso dentro de un tutorial guiado.
  static const advance = '${_base}ui_advance.mp3';

  /// Operación completada con éxito (PIN configurado, trámite generado).
  static const success = '${_base}ui_success.mp3';

  /// Firma de bienvenida al entrar a la app (tras login, desbloqueo por PIN o
  /// restauración de sesión). El único sonido largo de la familia: marca un
  /// momento, no una acción.
  static const welcome = '${_base}ui_welcome.mp3';

  /// Entrada inválida o acción rechazada. Informa, no regaña.
  static const error = '${_base}ui_error.mp3';

  /// Aviso que exige atención (modal de advertencia).
  static const alert = '${_base}ui_alert.mp3';
}
