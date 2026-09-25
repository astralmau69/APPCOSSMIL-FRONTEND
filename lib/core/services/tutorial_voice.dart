import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../utils/app_logger.dart';

/// Voz de la instructora del tutorial: reproduce los clips
/// `assets/vof_tutorial/<id>.mp3` (generados con RVC — ver `tools/rvc/`) y
/// expone su DURACIÓN para sincronizar la animación con lo que dura la locución.
///
/// Contrato pensado para el "gating audio-primero": [play] intenta reproducir y
/// SOLO devuelve una duración si el audio realmente arrancó. Si el clip falta,
/// está silenciado o falla, devuelve `null` en silencio — y quien llama NO debe
/// cambiar el estado de animación (la instructora se queda como esté). Así, sin
/// voz, no hay coreografía de "hablar".
/// Locución en curso: cuánto dura y con qué [token] se la identifica. El token
/// es lo que permite a quien anima descartar resultados y eventos de un clip
/// que ya fue reemplazado (ver [TutorialVoice.currentToken]).
typedef VoiceClip = ({Duration duration, int token});

class TutorialVoice {
  TutorialVoice._();

  static AudioPlayer? _instance;

  /// El reproductor, creado en el primer [play] y reutilizado después: la voz
  /// de la instructora es una sola y nunca se solapa consigo misma.
  static AudioPlayer get _player =>
      _instance ??= (AudioPlayer()..setReleaseMode(ReleaseMode.stop));

  /// Tira el reproductor para que el próximo [play] arranque con uno nuevo.
  ///
  /// Solo para tests, y no es una manía de aislamiento: audioplayers guarda
  /// `Completer`s dentro del reproductor, y un `Completer` entrega su
  /// resultado en la zona async donde se creó. Cada `testWidgets` corre en su
  /// propia zona, así que un reproductor heredado del test anterior espera
  /// para siempre en una zona ya muerta y deja colgado a todo el archivo.
  @visibleForTesting
  static void debugResetPlayer() {
    _instance?.dispose();
    _instance = null;
    _wiredTo = null;
    _token = 0;
  }

  /// Interruptor global (botón de silencio del tutorial).
  static bool enabled = true;

  /// Ficha del clip vigente. La incrementan [play] y [stop], así que cualquier
  /// futuro o evento que traiga un token distinto pertenece a una locución ya
  /// superada y debe ignorarse.
  ///
  /// Hace falta porque el reproductor es un singleton estático y en los
  /// recorridos push conviven VARIOS coaches montados a la vez (la pantalla
  /// anterior no se destruye al hacer push): sin el token, el `complete` del
  /// clip anterior apagaba la animación de habla del paso nuevo, y un `play()`
  /// que resolvía tarde sincronizaba la coreografía con la duración del clip
  /// equivocado.
  static int _token = 0;
  static int get currentToken => _token;

  static final StreamController<int> _completions =
      StreamController<int>.broadcast();
  static AudioPlayer? _wiredTo;

  /// Emite el token del clip que acaba de terminar. Compáralo con el token que
  /// devolvió [play] antes de reaccionar.
  static Stream<int> get onComplete {
    // Se cablea una vez POR reproductor: al renovarlo en tests, el stream del
    // anterior ya no emite y el nuevo tiene que quedar escuchado.
    if (_wiredTo != _player) {
      _wiredTo = _player;
      _player.onPlayerComplete.listen((_) => _completions.add(_token));
    }
    return _completions.stream;
  }

  /// Reproduce el clip [id] (`assets/vof_tutorial/<id>.mp3`).
  ///
  /// Dispara la reproducción ANTES de devolver, y retorna duración + token si
  /// arrancó; `null` si está silenciado, ausente, falla, o si otra llamada lo
  /// reemplazó mientras se preparaba. El llamador usa ese `null` para NO
  /// iniciar la animación de voz.
  static Future<VoiceClip?> play(String id) async {
    if (!enabled) return null;
    final token = ++_token;
    try {
      await _player.stop();
      if (token != _token) return null; // otro paso pidió su clip mientras
      await _player.setSource(AssetSource('vof_tutorial/$id.mp3'));
      if (token != _token) return null;
      // La duración a veces no está lista justo tras setSource; se espera un
      // instante al evento antes de rendirse.
      var dur = await _player.getDuration();
      dur ??= await _player.onDurationChanged.first.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => Duration.zero,
      );
      if (token != _token) return null;
      await _player.resume();
      if (token != _token) return null;
      // Sin metadatos de duración fiables no hay coreografía que sincronizar.
      if (dur == Duration.zero) return null;
      return (duration: dur, token: token);
    } catch (e) {
      // Sin clip para este paso: se sigue sin voz, sin ruido en logs de release.
      AppLogger.debug('TutorialVoice', 'sin clip "$id": $e');
      return null;
    }
  }

  /// Corta la locución en curso (al salir del tutorial o cambiar de paso).
  /// Invalida el token: lo que quedara en vuelo del clip cortado se descarta.
  static Future<void> stop() async {
    _token++;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Un coach saliente solo puede cancelar la locución que él solicitó,
  /// incluso si todavía está preparándose. Nunca corta la del coach entrante.
  static Future<void> stopIfToken(int token) async {
    if (token == _token) await stop();
  }
}
