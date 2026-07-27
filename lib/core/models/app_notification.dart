import 'dart:convert';

/// Tipos de notificación soportados por COSSMIL.
enum AppNotificationType {
  reminder, // Recordatorio de cita
  booking, // Confirmación de reserva
  rating, // Solicitud de calificación
  cazador, // Cazador de fichas
}

/// Modelo inmutable de una notificación en el historial del usuario.
class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? payload;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.payload,
  });

  AppNotification copyWith({
    String? id,
    AppNotificationType? type,
    String? title,
    String? body,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? payload,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    if (payload != null) 'payload': payload,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: AppNotificationType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? ''),
        orElse: () => AppNotificationType.reminder,
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  /// Ícono representativo del tipo.
  static const Map<AppNotificationType, int> _icons = {
    AppNotificationType.reminder: 0xF4C3, // clock.fill (CupertinoIcons)
    AppNotificationType.booking: 0xF437, // checkmark.seal.fill
    AppNotificationType.rating: 0xF48A, // star.fill
    AppNotificationType.cazador: 0xF4B3, // bell.fill
  };

  int get iconCodePoint => _icons[type] ?? 0xF4B3;

  @override
  String toString() => 'AppNotification(id=$id, type=$type, isRead=$isRead)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppNotification && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Repositorio de notificaciones en memoria (singleton por sesión).
/// La persistencia se delega a [NotificationHistoryStorage].
class AppNotificationRepository {
  AppNotificationRepository._();

  static final List<AppNotification> _items = [];

  static List<AppNotification> get all => List.unmodifiable(_items);

  static int get unreadCount => _items.where((n) => !n.isRead).length;

  static void addOrUpdate(AppNotification notif) {
    final idx = _items.indexWhere((n) => n.id == notif.id);
    if (idx >= 0) {
      _items[idx] = notif;
    } else {
      _items.insert(0, notif);
    }
  }

  static void markAsRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(isRead: true);
    }
  }

  static void markAllAsRead() {
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
  }

  static void remove(String id) => _items.removeWhere((n) => n.id == id);

  static void clear() => _items.clear();

  /// Carga la lista desde JSON serializado.
  static void loadFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _items
        ..clear()
        ..addAll(
          list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)),
        );
    } catch (_) {}
  }

  /// Serializa la lista actual a JSON.
  static String toJson() => jsonEncode(_items.map((n) => n.toJson()).toList());
}
