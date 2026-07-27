import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_sounds.dart';

/// Gestiona el estado de sonido de la app (no afecta notificaciones del sistema).
///
/// Similar a [ThemeManager], usa un [ValueNotifier] para que los widgets
/// reaccionen al cambio sin Provider/Riverpod.
class SoundManager {
  SoundManager._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
  );
  static const _key = 'app_sound_enabled';

  /// `true` = sonidos activados (default), `false` = silenciados.
  static final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier(true);

  /// Atajo para verificar si los sonidos están habilitados.
  static bool get isEnabled => soundEnabledNotifier.value;

  /// Inicializa el estado desde almacenamiento persistente.
  /// Llamar al arranque de la app (ej: en main o splash).
  static Future<void> init() async {
    try {
      final stored = await _storage.read(key: _key);
      if (stored != null) {
        soundEnabledNotifier.value = stored == 'true';
      }
    } catch (e) {
      debugPrint('⚠️ SoundManager: no se pudo leer preferencia de sonido: $e');
    }
  }

  /// Activa/desactiva los sonidos y persiste la preferencia.
  static Future<void> setEnabled(bool enabled) async {
    soundEnabledNotifier.value = enabled;
    try {
      await _storage.write(key: _key, value: enabled.toString());
    } catch (e) {
      debugPrint(
        '⚠️ SoundManager: no se pudo guardar preferencia de sonido: $e',
      );
    }
  }

  /// Alterna el estado de sonido.
  static Future<void> toggle() async {
    await setEnabled(!soundEnabledNotifier.value);
  }

  /// Returns true if the Android device ringer is in silent (0) or vibrate (1) mode.
  /// Always returns false on iOS (handled by AVAudioSession ambient category in main.dart).
  static Future<bool> isDeviceSilentOrVibrate() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    try {
      const ch = MethodChannel('cossmil.audio/ringer');
      final mode = await ch.invokeMethod<int>('getRingerMode');
      return (mode ?? 2) <= 1; // 0=SILENT, 1=VIBRATE → don't play
    } catch (_) {
      return false;
    }
  }

  // ─── Caché del modo silencio ──────────────────────────────────────────────
  // Consultar el ringer es un salto por MethodChannel a la plataforma. Hacerlo
  // en CADA toque metía un round-trip asíncrono antes de sonar: el blip
  // llegaba tarde respecto al dedo y la interfaz se sentía "floja". Se cachea
  // por un rato corto — suficiente para una ráfaga de toques, lo bastante
  // breve para respetar al usuario que acaba de mover el interruptor.
  static bool? _silentCache;
  static DateTime? _silentCacheAt;
  static const _silentTtl = Duration(seconds: 2);

  static Future<bool> _isSilentCached() async {
    final at = _silentCacheAt;
    if (_silentCache != null &&
        at != null &&
        DateTime.now().difference(at) < _silentTtl) {
      return _silentCache!;
    }
    final v = await isDeviceSilentOrVibrate();
    _silentCache = v;
    _silentCacheAt = DateTime.now();
    return v;
  }

  /// Invalida la caché del modo silencio. La llama el shell al volver del
  /// segundo plano: el usuario pudo haber cambiado el interruptor fuera de la
  /// app.
  static void invalidateSilentCache() {
    _silentCache = null;
    _silentCacheAt = null;
  }

  /// Última "voz" reproducida por [playIfAllowed]. Se usa para detenerla antes
  /// de iniciar otra y evitar que dos clips se solapen (en web, al re-loguear o
  /// recargar, dos LoginScreen podían reproducir el mismo audio a la vez,
  /// produciendo un efecto "duplicado/robótico").
  static AudioPlayer? _activeVoice;

  /// Registra una locución lanzada FUERA de [playIfAllowed]. El splash maneja
  /// su propio player (setSource + resume es más fiable en el primer arranque)
  /// y sin esto el resto del sistema no sabría que hay una voz sonando.
  static void registerVoice(AudioPlayer player) => _activeVoice = player;

  /// true si hay una locución sonando ahora mismo. Lo consulta quien no quiera
  /// encimarse a una voz — por ejemplo la firma de bienvenida, que se calla si
  /// la locución del splash sigue en curso.
  static bool get isVoicePlaying => _activeVoice?.state == PlayerState.playing;

  // ─── Pool de reproductores para los blips de interfaz ─────────────────────
  // Construir un AudioPlayer por toque cuesta una asignación y el montaje de
  // su canal nativo; en ráfagas (teclado del PIN, cambio rápido de pestañas)
  // eso se notaba como tirones. Se reciclan unos pocos en rueda: el más viejo
  // se corta si hacen falta más voces simultáneas, que es exactamente lo que
  // hace un motor de sonido de interfaz.
  static final List<AudioPlayer> _uiPool = [];
  static int _uiSlot = 0;
  static const _uiPoolSize = 4;

  /// Antirrebote: dos peticiones del MISMO sonido más juntas que esto suenan
  /// una sola vez. Evita el "eco" cuando un gesto dispara dos callbacks.
  static const _uiDebounce = Duration(milliseconds: 45);
  static final Map<String, DateTime> _lastPlayed = {};

  /// Gancho de pruebas: recibe cada sonido que SÍ llega a reproducirse (ya
  /// pasado el filtro de preferencia y el antirrebote). En producción es nulo
  /// y no cuesta nada; existe porque [playUi] traga sus errores a propósito y
  /// sin esto no habría forma de comprobar qué se disparó.
  @visibleForTesting
  static void Function(String asset)? debugPlayHook;

  /// Limpia el estado del antirrebote entre pruebas (es estático y, si no, un
  /// test contaminaría al siguiente).
  @visibleForTesting
  static void debugResetThrottle() => _lastPlayed.clear();

  /// Prepara el motor de sonido antes del primer toque: crea los
  /// reproductores del pool y deja los blips de interacción ya extraídos del
  /// bundle. Sin esto, el PRIMER sonido de la sesión llega tarde (hay que
  /// copiar el asset a disco antes de sonar) y esa primera impresión es justo
  /// la que define si la app se siente sólida. Se llama al arranque y nunca
  /// bloquea: si algo falla, se sigue sin sonido.
  static Future<void> warmUp() async {
    try {
      while (_uiPool.length < _uiPoolSize) {
        _uiPool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      }
      await AudioCache.instance.loadAll([
        AppSounds.tap,
        AppSounds.nav,
        AppSounds.select,
      ]);
    } catch (_) {}
  }

  static AudioPlayer _nextUiPlayer() {
    if (_uiPool.length < _uiPoolSize) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _uiPool.add(p);
      return p;
    }
    final p = _uiPool[_uiSlot];
    _uiSlot = (_uiSlot + 1) % _uiPoolSize;
    return p;
  }

  /// Reproduce un blip corto de interfaz (toque, cambio de pestaña, éxito,
  /// error…) respetando la preferencia de sonido y el modo silencio del
  /// dispositivo. Usa las constantes de `AppSounds`, nunca rutas sueltas.
  ///
  /// A diferencia de [playIfAllowed], NO detiene la voz activa: los blips
  /// acompañan, no protagonizan — nunca deben cortar una locución.
  static Future<void> playUi(String assetPath, {double volume = 0.55}) async {
    if (!isEnabled) return;

    // El antirrebote va ANTES del await: si se resolviera después, dos toques
    // simultáneos pasarían ambos el filtro antes de que ninguno lo marque.
    final now = DateTime.now();
    final last = _lastPlayed[assetPath];
    if (last != null && now.difference(last) < _uiDebounce) return;
    _lastPlayed[assetPath] = now;
    debugPlayHook?.call(assetPath);

    if (await _isSilentCached()) return;
    try {
      final player = _nextUiPlayer();
      await player.stop();
      await player.play(AssetSource(assetPath), volume: volume);
    } catch (_) {}
  }

  /// Plays an audio asset only if in-app sounds are enabled AND the device
  /// is not in silent/vibrate mode. Returns the AudioPlayer so the caller
  /// can stop/dispose it if needed; returns null if playback was skipped.
  ///
  /// Antes de reproducir, detiene cualquier voz previa lanzada por este método,
  /// garantizando que solo suene un clip a la vez.
  static Future<AudioPlayer?> playIfAllowed(String assetPath) async {
    if (!isEnabled) return null;
    if (await isDeviceSilentOrVibrate()) return null;

    // Silenciar la voz anterior para que no se solape con la nueva.
    try {
      await _activeVoice?.stop();
    } catch (_) {}

    try {
      final player = AudioPlayer();
      _activeVoice = player;
      await player.play(AssetSource(assetPath));
      return player;
    } catch (_) {
      return null;
    }
  }
}
