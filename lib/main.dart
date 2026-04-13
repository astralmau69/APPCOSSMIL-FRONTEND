import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/theme/sound_manager.dart';
import 'core/theme/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Initialize Spanish locale for date formatting
  await initializeDateFormatting('es');
  // Initialize notification channels + timezone before app launch
  await NotificationService.initialize();
  // Restore sound preference
  await SoundManager.init();
  // Restore theme preference (REPORTE 001)
  await ThemeManager.init();
  // Configurar audio para transmisión y Screen Mirroring
  //   iOS  → AVAudioSessionCategory.ambient (respeta el switch de silencio)
  //   Android → AndroidUsageType.media (para que el sonido pase por screen mirroring a la TV)
  await AudioPlayer.global.setAudioContext(
    AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media, // <-- Cambiado a 'media' para screen mirroring
        audioFocus: AndroidAudioFocus.gainTransientMayDuck, // <-- Focus más gentil para sonidos cortos
      ),
    ),
  );
  runApp(const CossmilApp());
}
