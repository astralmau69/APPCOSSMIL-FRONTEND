import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../session/user_session.dart';
import 'push_notification_service.dart';

/// Servicio para gestionar la lista de médicos favoritos del usuario (local y nube).
///
/// Guarda los médicos favoritos localmente usando [SharedPreferences] para acceso offline
/// rápido, y los sincroniza en tiempo real con **Firebase Cloud Firestore**.
class FavoritesService {
  FavoritesService._();

  static const String _keyFavorites = 'favorite_doctors_list_v2';
  static const String _tag = 'FavoritesService';

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

  /// Añade o quita un médico de la lista de favoritos (tanto en local como en Firestore).
  ///
  /// Retorna `true` si el médico fue agregado, y `false` si fue removido.
  static Future<bool> toggleFavorite(String doctorId, {Map<String, dynamic>? details}) async {
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

    // Guardar localmente
    final encoded = favs.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_keyFavorites, encoded);

    // Guardar en Firestore si el usuario está logueado
    if (UserSession.isLoggedIn) {
      final userId = UserSession.currentUser.id;
      if (userId.isNotEmpty) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('favorites')
              .doc(doctorId);

          if (isAdded) {
            await docRef.set({
              ...finalDetails,
              'syncedAt': FieldValue.serverTimestamp(),
            });
          } else {
            await docRef.delete();
          }
          debugPrint('[$_tag] Sincronizado en Firestore con éxito: $doctorId (added: $isAdded)');
        } catch (e) {
          debugPrint('[$_tag] Error sincronizando favorito en Firestore: $e');
        }
      }
    }

    return isAdded;
  }

  /// Descarga los favoritos de Firestore de la cuenta del usuario actual,
  /// actualiza SharedPreferences y registra las suscripciones de notificaciones FCM.
  static Future<void> syncFavoritesWithCloud() async {
    if (!UserSession.isLoggedIn) {
      debugPrint('[$_tag] Sincronización omitida: Usuario no logueado');
      return;
    }

    final userId = UserSession.currentUser.id;
    if (userId.isEmpty) return;

    try {
      debugPrint('[$_tag] Iniciando descarga de favoritos desde Firestore...');
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      final cloudFavs = snap.docs.map((doc) => doc.data()).toList();
      debugPrint('[$_tag] Descargados ${cloudFavs.length} médico(s) favorito(s) de Firestore');

      // Actualizar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final encoded = cloudFavs.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(_keyFavorites, encoded);

      // Si no es Web, suscribir el dispositivo a los temas FCM
      if (!kIsWeb) {
        for (final doc in cloudFavs) {
          final idmed = doc['idmed']?.toString() ?? '';
          if (idmed.isNotEmpty) {
            await PushNotificationService.subscribeToDoctor(idmed);
          }
        }
      }
      debugPrint('[$_tag] Sincronización local y notificaciones push completada');
    } catch (e) {
      debugPrint('[$_tag] Error descargando favoritos desde Firestore: $e');
    }
  }
}
