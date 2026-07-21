import 'package:shared_preferences/shared_preferences.dart';

/// Controla qué tutoriales guiados ya vio el usuario, para mostrarlos
/// automáticamente solo la primera vez (y permitir volver a verlos desde
/// Perfil cuando quiera).
///
/// Mismo patrón que [PermissionsOnboarding]: un flag booleano persistido con
/// `shared_preferences`, versionado (`_v1`) por si en el futuro se rediseña
/// un tutorial y se quiere volver a mostrarlo sin reutilizar el flag viejo.
class TutorialService {
  TutorialService._();

  static const _kFichaSeen = 'tutorial_ficha_seen_v1';

  /// true si el tutorial de "sacar una ficha" ya se mostró (aceptado o
  /// descartado) en este dispositivo.
  static Future<bool> hasSeenFichaTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFichaSeen) ?? false;
  }

  /// Marca el tutorial de "sacar una ficha" como visto. Se llama apenas el
  /// usuario responde la invitación (acepte o la descarte), para que nunca
  /// vuelva a aparecer sola — solo bajo demanda desde Perfil.
  static Future<void> markFichaTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kFichaSeen, true);
  }
}
