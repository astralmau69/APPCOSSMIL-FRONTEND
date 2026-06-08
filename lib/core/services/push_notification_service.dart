import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/app_logger.dart';
import 'notification_initializer.dart';
import '../session/user_session.dart';
import 'notification_ui.dart';
import 'notification_preferences.dart';
import '../models/app_notification.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Cuando se recibe en segundo plano o cerrada
  await Firebase.initializeApp();
  AppLogger.debug('PushNotificationService', 'Mensaje FCM recibido en background: ${message.messageId}');
}

/// Servicio central para gestionar las Notificaciones Push de Firebase (FCM).
///
/// Permite obtener el Token de FCM e imprimirlo en consola para pruebas,
/// y procesa las notificaciones entrantes en primer plano y segundo plano.
class PushNotificationService {
  PushNotificationService._();

  static const _tag = 'PushNotificationService';
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Registrar handler de background
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Solicitar permisos para iOS y web (en Android se solicitan localmente)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      AppLogger.info(_tag, 'Permiso de notificaciones push: ${settings.authorizationStatus}');

      // 3. Obtener token de FCM
      final token = await _messaging.getToken();
      AppLogger.info(_tag, '════════════════════════════════════════════════════════════');
      AppLogger.info(_tag, 'FCM Token (Copiar para pruebas en Consola Firebase):');
      AppLogger.info(_tag, '$token');
      AppLogger.info(_tag, '════════════════════════════════════════════════════════════');

      // 4. Escuchar cambios de token
      _messaging.onTokenRefresh.listen((newToken) {
        AppLogger.info(_tag, 'FCM Token actualizado: $newToken');
        // Aquí se enviaría el token al backend de producción cuando esté disponible
      });

      // 5. Configurar listener para mensajes en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppLogger.debug(_tag, 'Mensaje FCM recibido en primer plano (Foreground): ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 6. Configurar listener cuando el usuario abre la app desde la notificación
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.debug(_tag, 'App abierta desde notificación FCM: ${message.data}');
        NotificationUiHandler.handleNotificationData(message.data);
      });

      // 7. Configurar getInitialMessage (cuando la app estaba cerrada y se abre por notificación)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        AppLogger.debug(_tag, 'App iniciada desde notificación FCM cerrada: ${initialMessage.data}');
        // Esperar un momento a que termine de inicializarse la UI antes de abrir la sección
        Future.delayed(const Duration(milliseconds: 1000), () {
          NotificationUiHandler.handleNotificationData(initialMessage.data);
        });
      }

      _initialized = true;
    } catch (e, st) {
      AppLogger.error(_tag, 'Error al inicializar PushNotificationService', e, st);
    }
  }

  /// Se suscribe al tema de notificaciones de un médico específico
  static Future<void> subscribeToDoctor(String doctorId) async {
    if (doctorId.isEmpty) return;
    try {
      await _messaging.subscribeToTopic('doctor_$doctorId');
      AppLogger.info(_tag, 'Suscrito con éxito al tema: doctor_$doctorId');
    } catch (e, st) {
      AppLogger.error(_tag, 'Error al suscribirse al tema doctor_$doctorId', e, st);
    }
  }

  /// Cancela la suscripción al tema de notificaciones de un médico específico
  static Future<void> unsubscribeFromDoctor(String doctorId) async {
    if (doctorId.isEmpty) return;
    try {
      await _messaging.unsubscribeFromTopic('doctor_$doctorId');
      AppLogger.info(_tag, 'Suscripción cancelada con éxito para el tema: doctor_$doctorId');
    } catch (e, st) {
      AppLogger.error(_tag, 'Error al cancelar la suscripción del tema doctor_$doctorId', e, st);
    }
  }

  /// Muestra una notificación local a partir del mensaje FCM recibido en primer plano
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      // Generar un ID único para la notificación
      final id = DateTime.now().millisecondsSinceEpoch % 100000;

      // Usar el canal existente con sonido personalizado para consistencia
      const androidDetails = AndroidNotificationDetails(
        'cossmil_reminder_v2',
        'Recordatorios de citas COSSMIL',
        channelDescription: 'Recordatorios automáticos antes de tu cita médica',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notificacion_cita'),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: 'notificacion_cita.mp3',
      );

      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Decodificar payload si existe en message.data
      final payloadMap = <String, dynamic>{
        'userId': UserSession.isLoggedIn ? UserSession.currentUser.id : '',
        ...message.data,
      };

      await NotificationInitializer.plugin.show(
        id,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(payloadMap),
      );

      // Persistir en el historial de notificaciones si el usuario está logueado
      if (UserSession.isLoggedIn) {
        final userId = UserSession.currentUser.id;
        final typeStr = message.data['type'] as String?;
        final type = typeStr == 'cazador'
            ? AppNotificationType.cazador
            : typeStr == 'rating'
                ? AppNotificationType.rating
                : typeStr == 'booking'
                    ? AppNotificationType.booking
                    : AppNotificationType.reminder;

        await NotificationPreferences.addToHistory(
          userId,
          AppNotification(
            id: 'push_${message.messageId ?? DateTime.now().millisecondsSinceEpoch}',
            type: type,
            title: notification.title ?? '',
            body: notification.body ?? '',
            createdAt: DateTime.now(),
            payload: payloadMap,
          ),
        );
      }
    }
  }
}
