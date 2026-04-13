import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gestiona el estado de sonido de la app (no afecta notificaciones del sistema).
///
/// Similar a [ThemeManager], usa un [ValueNotifier] para que los widgets
/// reaccionen al cambio sin Provider/Riverpod.
class SoundManager {
  SoundManager._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
      debugPrint('⚠️ SoundManager: no se pudo guardar preferencia de sonido: $e');
    }
  }

  /// Alterna el estado de sonido.
  static Future<void> toggle() async {
    await setEnabled(!soundEnabledNotifier.value);
  }

  /// Returns true if the Android device ringer is in silent (0) or vibrate (1) mode.
  /// Always returns false on iOS (handled by AVAudioSession ambient category in main.dart).
  static Future<bool> isDeviceSilentOrVibrate() async {
    if (!Platform.isAndroid) return false;
    try {
      const ch = MethodChannel('cossmil.audio/ringer');
      final mode = await ch.invokeMethod<int>('getRingerMode');
      return (mode ?? 2) <= 1; // 0=SILENT, 1=VIBRATE → don't play
    } catch (_) {
      return false;
    }
  }

  /// Plays an audio asset only if in-app sounds are enabled AND the device
  /// is not in silent/vibrate mode. Returns the AudioPlayer so the caller
  /// can stop/dispose it if needed; returns null if playback was skipped.
  static Future<AudioPlayer?> playIfAllowed(String assetPath) async {
    if (!isEnabled) return null;
    if (await isDeviceSilentOrVibrate()) return null;
    try {
      final player = AudioPlayer();
      await player.play(AssetSource(assetPath));
      return player;
    } catch (_) {
      return null;
    }
  }
}
