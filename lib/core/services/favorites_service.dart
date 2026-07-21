import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar la lista de médicos favoritos del usuario (local).
///
/// Guarda los médicos favoritos localmente usando [SharedPreferences] para
/// acceso offline rápido. La suscripción a notificaciones push (FCM) por médico
/// se maneja aparte en las pantallas mediante
/// [PushNotificationService.subscribeToDoctor] / unsubscribeFromDoctor.
class FavoritesService {
  FavoritesService._();

  static const String _keyFavorites = 'favorite_doctors_list_v2';

  /// Retorna la lista de los médicos favoritos con sus detalles.
  static Future<List<Map<String, dynamic>>> getFavoriteDoctors() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyFavorites) ?? [];
    return list.map((s) {
      try {
        return Map<String, dynamic>.from(jsonDecode(s) as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  /// Retorna la lista de los IDs de los médicos favoritos.
  static Future<List<String>> getFavoriteDoctorIds() async {
    final favs = await getFavoriteDoctors();
    return favs
        .map((m) => m['idmed']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Verifica si un médico específico está marcado como favorito.
  static Future<bool> isFavorite(String doctorId) async {
    final favorites = await getFavoriteDoctorIds();
    return favorites.contains(doctorId);
  }

  /// Añade o quita un médico de la lista de favoritos (solo local).
  ///
  /// Retorna `true` si el médico fue agregado, y `false` si fue removido.
  static Future<bool> toggleFavorite(String doctorId,
      {Map<String, dynamic>? details}) async {
    if (doctorId.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavoriteDoctors();

    final index = favs.indexWhere((m) => m['idmed'] == doctorId);
    final bool isAdded;
    final Map<String, dynamic> finalDetails = details ?? {'idmed': doctorId};

    if (index >= 0) {
      favs.removeAt(index);
      isAdded = false;
    } else {
      favs.add(finalDetails);
      isAdded = true;
    }

    final encoded = favs.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_keyFavorites, encoded);

    return isAdded;
  }
}
