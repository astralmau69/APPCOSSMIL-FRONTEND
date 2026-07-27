import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_notification.dart';
import '../utils/app_logger.dart';

/// Preferencias de notificación del usuario.
///
/// Persiste en [FlutterSecureStorage] con clave por userId para que
/// múltiples cuentas en el mismo dispositivo tengan preferencias independientes.
class NotificationPreferences {
  NotificationPreferences._();

  static const _tag = 'NotificationPreferences';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      sharedPreferencesName: 'cossmil_secure_prefs',
    ),
  );

  // ── Claves (prefijadas por userId) ─────────────────────────────────────────

  static String _key(String userId, String pref) =>
      'notif_pref_${userId}_$pref';

  static const _kReminders = 'reminders';
  static const _kConfirmations = 'confirmations';
  static const _kRatings = 'ratings';
  static const _kCazador = 'cazador';
  static const _kHistory = 'history';

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Recordatorios de cita (2d, 1d, 3h, 30min, 15min).
  static Future<bool> getReminders(String userId) =>
      _readBool(userId, _kReminders, defaultValue: true);

  /// Confirmación inmediata 5 min tras reservar.
  static Future<bool> getConfirmations(String userId) =>
      _readBool(userId, _kConfirmations, defaultValue: true);

  /// Solicitud de calificación tras ser atendido.
  static Future<bool> getRatings(String userId) =>
      _readBool(userId, _kRatings, defaultValue: true);

  /// Cazador de fichas (notificación al abrirse un cupo).
  static Future<bool> getCazador(String userId) =>
      _readBool(userId, _kCazador, defaultValue: true);

  // ── Setters ────────────────────────────────────────────────────────────────

  static Future<void> setReminders(String userId, bool value) =>
      _writeBool(userId, _kReminders, value);

  static Future<void> setConfirmations(String userId, bool value) =>
      _writeBool(userId, _kConfirmations, value);

  static Future<void> setRatings(String userId, bool value) =>
      _writeBool(userId, _kRatings, value);

  static Future<void> setCazador(String userId, bool value) =>
      _writeBool(userId, _kCazador, value);

  // ── Historial de notificaciones ────────────────────────────────────────────

  /// Carga el historial del usuario desde storage (últimos 30 días).
  static Future<void> loadHistory(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId, _kHistory));
      if (raw != null && raw.isNotEmpty) {
        AppNotificationRepository.loadFromJson(raw);
        // Purgar notificaciones de más de 30 días
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        final all = AppNotificationRepository.all;
        for (final n
            in all.where((n) => n.createdAt.isBefore(cutoff)).toList()) {
          AppNotificationRepository.remove(n.id);
        }
      }
    } catch (e) {
      AppLogger.warn(_tag, 'loadHistory failed: $e');
    }
  }

  /// Persiste el historial actual del usuario.
  static Future<void> saveHistory(String userId) async {
    try {
      final raw = AppNotificationRepository.toJson();
      await _storage.write(key: _key(userId, _kHistory), value: raw);
    } catch (e) {
      AppLogger.warn(_tag, 'saveHistory failed: $e');
    }
  }

  /// Agrega una notificación al historial y persiste.
  static Future<void> addToHistory(String userId, AppNotification notif) async {
    AppNotificationRepository.addOrUpdate(notif);
    await saveHistory(userId);
  }

  /// Marca como leída y persiste.
  static Future<void> markRead(String userId, String notifId) async {
    AppNotificationRepository.markAsRead(notifId);
    await saveHistory(userId);
  }

  /// Elimina una notificación del historial y persiste.
  static Future<void> deleteNotif(String userId, String notifId) async {
    AppNotificationRepository.remove(notifId);
    await saveHistory(userId);
  }

  // ── Helpers internos ───────────────────────────────────────────────────────

  static Future<bool> _readBool(
    String userId,
    String pref, {
    required bool defaultValue,
  }) async {
    try {
      final raw = await _storage.read(key: _key(userId, pref));
      if (raw == null) return defaultValue;
      return raw == '1';
    } catch (_) {
      return defaultValue;
    }
  }

  static Future<void> _writeBool(String userId, String pref, bool value) async {
    try {
      await _storage.write(key: _key(userId, pref), value: value ? '1' : '0');
    } catch (e) {
      AppLogger.warn(_tag, 'writeBool $pref failed: $e');
    }
  }
}
