import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/services/push_notification_service.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_sync_service.dart';
import 'core/theme/sound_manager.dart';
import 'core/theme/theme_manager.dart';

void main() async {
  // Seguridad: en producción (release) silenciar TODA la consola para no
  // filtrar datos (URLs con matrícula, tokens, datos personales, etc.).
  // En debug se mantienen los logs para desarrollo.
  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase.
  // En web el SDK JS se descarga de gstatic.com en tiempo de ejecución; si el
  // dispositivo no tiene internet (acceso solo por LAN) esa carga puede
  // colgarse y runApp() nunca correría -> pantalla en blanco. El timeout
  // garantiza que el arranque continúe aunque Firebase no esté disponible.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(kIsWeb ? const Duration(seconds: 8) : const Duration(seconds: 30));
    // FCM en web exige service worker + API Notification, que solo existen en
    // contextos seguros (https o localhost). Desde http://IP:puerto no hay
    // forma de que funcione: se omite para no lanzar errores en consola.
    final webPushSupported = !kIsWeb ||
        Uri.base.scheme == 'https' ||
        Uri.base.host == 'localhost' ||
        Uri.base.host == '127.0.0.1';
    if (webPushSupported) {
      await PushNotificationService.initialize()
          .timeout(kIsWeb ? const Duration(seconds: 8) : const Duration(seconds: 30));
    }
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Initialize Spanish locale for date formatting
  await initializeDateFormatting('es');
  // Initialize notification channels + timezone before app launch (mobile only)
  if (!kIsWeb) {
    await NotificationService.initialize();
    // Registra el motor de WorkManager para la sincronización periódica sin
    // Firebase (ver BackgroundSyncService) — el agendado real ocurre recién
    // tras login/restauración de sesión, en LoadingDataScreen.
    await BackgroundSyncService.initialize();
  }
  // Restore sound preference
  await SoundManager.init();
  // Restore theme preference (REPORTE 001)
  await ThemeManager.init();
  // Configurar audio para transmisión y Screen Mirroring (mobile only)
  //   iOS  → AVAudioSessionCategory.ambient (respeta el switch de silencio)
  //   Android → AndroidUsageType.media (para que el sonido pase por screen mirroring a la TV)
  if (!kIsWeb) {
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
  }
  runApp(const CossmilApp());
}
