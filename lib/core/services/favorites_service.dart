import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar localmente la lista de médicos favoritos del usuario.
///
/// Guarda los IDs y detalles de los médicos favoritos usando [SharedPreferences] para que
/// el estado se mantenga estable entre ejecuciones.
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
    return favs.map((m) => m['idmed']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
  }

  /// Verifica si un médico específico está marcado como favorito.
  static Future<bool> isFavorite(String doctorId) async {
    final favorites = await getFavoriteDoctorIds();
    return favorites.contains(doctorId);
  }

  /// Añade o quita un médico de la lista de favoritos.
  ///
  /// Retorna `true` si el médico fue agregado, y `false` si fue removido.
  static Future<bool> toggleFavorite(String doctorId, {Map<String, dynamic>? details}) async {
    if (doctorId.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final favs = await getFavoriteDoctors();

    final index = favs.indexWhere((m) => m['idmed'] == doctorId);
    final bool isAdded;

    if (index >= 0) {
      favs.removeAt(index);
      isAdded = false;
    } else {
      final newFav = details ?? {'idmed': doctorId};
      favs.add(newFav);
      isAdded = true;
    }

    final encoded = favs.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_keyFavorites, encoded);
    return isAdded;
  }
}
