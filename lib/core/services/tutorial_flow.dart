import 'package:flutter/foundation.dart';

/// Tutoriales guiados que recorren pantallas push reales (a diferencia del de
/// "sacar una ficha", que vive dentro del flujo contenido de Reservar y se
/// controla con `bookingState.isTutorialMode`).
enum GuidedTutorial {
  none,

  /// "Cómo sacar una ficha". No usa [TutorialFlowHost]: vive dentro del flujo
  /// contenido de Reservar y se controla con `bookingState.isTutorialMode`.
  /// Aparece en este enum porque su PRIMER paso sí ocurre en el menú de
  /// Inicio, igual que los demás.
  ficha,

  calendario,
  tramites,
}

/// Controla qué tutorial guiado de pantallas push está activo.
///
/// Singleton estático (mismo patrón que `UserSession`): las pantallas de
/// Calendario y Procedimientos no reciben `tabShell` en el constructor, así
/// que el estado del recorrido vive aquí y cada pantalla lo observa vía
/// `TutorialFlowHost`. Lo enciende TabShell (Perfil → AYUDA); se apaga desde
/// el propio coach, al terminar el recorrido, o en silencio si el usuario
/// cambia de tab o abandona la pantalla raíz del recorrido.
///
/// Ambos recorridos son inofensivos por construcción: Calendario es solo
/// lectura y el de Trámites termina ANTES de generar ningún documento, así
/// que no necesitan datos simulados ni bloqueos de negocio.
///
/// Los TRES tutoriales arrancan en el menú de Inicio: la instructora espera
/// ahí y pide tocar la misma tarjeta que el usuario usará de verdad, para que
/// aprenda el camino completo y no solo la pantalla de destino. Ese primer
/// paso lo lleva `TabShell.homeTutorialNotifier`.
class TutorialFlow {
  TutorialFlow._();

  static final ValueNotifier<GuidedTutorial> active = ValueNotifier(
    GuidedTutorial.none,
  );

  static void start(GuidedTutorial tutorial) => active.value = tutorial;

  static void stop() => active.value = GuidedTutorial.none;
}
