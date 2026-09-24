import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

/// Tests del COACH (burbujas, insignia, contador, accesibilidad).
///
/// Vivían mezclados con los de la instructora en `tutorial_instructor_test.dart`.
/// Se separaron al pasar la instructora a un rig: son dos responsabilidades
/// distintas y sólo una cambió.
void main() {
  testWidgets('TutorialCoachOverlay muestra instructora, insignia y burbujas', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Stack(
            children: [
              const SizedBox.expand(),
              TutorialCoachOverlay(
                messages: const [
                  '¡Hola! Vamos a sacar tu primera ficha juntos.',
                  'Primero elige tu hospital o policlínico.',
                ],
                isDark: false,
                onExit: () {},
                step: 1,
                totalSteps: 6,
              ),
            ],
          ),
        ),
      ),
    );
    // Revelado tipo chat: la primera burbuja aparece pronto, la segunda espera
    // tras el indicador de "escribiendo…".
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(TutorialInstructor), findsOneWidget);
    expect(find.text('MODO ENTRENAMIENTO · PASO 1/6'), findsOneWidget);
    expect(
      find.text('¡Hola! Vamos a sacar tu primera ficha juntos.'),
      findsOneWidget,
    );
    // Aún no llegó: la instructora está "escribiendo".
    expect(find.text('Primero elige tu hospital o policlínico.'), findsNothing);

    // Pasado el tecleo, la segunda burbuja ya está.
    await tester.pump(const Duration(milliseconds: 1600));
    expect(
      find.text('Primero elige tu hospital o policlínico.'),
      findsOneWidget,
    );

    // Tras el tiempo de lectura, el coach se minimiza solo: las burbujas se
    // desvanecen (siguen en el árbol con opacidad 0) para no tapar el flujo.
    await tester.pump(const Duration(seconds: 17));
    await tester.pump(const Duration(milliseconds: 400));
    final bubblesOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text('¡Hola! Vamos a sacar tu primera ficha juntos.'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(bubblesOpacity.opacity, 0.0);
  });

  testWidgets('Entre burbujas aparece el indicador de "escribiendo…"', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Stack(
            children: [
              const SizedBox.expand(),
              TutorialCoachOverlay(
                messages: const [
                  'Primera pista.',
                  'Segunda pista, un poco más larga que la anterior.',
                ],
                isDark: false,
                onExit: () {},
                step: 1,
                totalSteps: 4,
              ),
            ],
          ),
        ),
      ),
    );

    final typing = find.byKey(const ValueKey('typing'));

    // Recién montado: primera burbuja visible, sin puntitos todavía.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Primera pista.'), findsOneWidget);
    expect(typing, findsNothing);

    // A mitad del "tecleo": los puntitos, y la segunda aún no llegó.
    await tester.pump(const Duration(milliseconds: 600));
    expect(typing, findsOneWidget);
    expect(
      find.text('Segunda pista, un poco más larga que la anterior.'),
      findsNothing,
    );

    // Terminado el tecleo: la segunda burbuja aparece y los puntitos se van.
    await tester.pump(const Duration(milliseconds: 1400));
    expect(
      find.text('Segunda pista, un poco más larga que la anterior.'),
      findsOneWidget,
    );
    expect(typing, findsNothing);

    // Consume el timer del auto-colapso para cerrar sin pendientes.
    await tester.pump(const Duration(seconds: 17));
  });

  testWidgets('Minimizado, el globito muestra el contador de paso', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Stack(
            children: [
              const SizedBox.expand(),
              TutorialCoachOverlay(
                messages: const ['Elige tu hospital.'],
                isDark: false,
                onExit: () {},
                step: 2,
                totalSteps: 7,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    AnimatedOpacity globito() => tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text('2/7'),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );

    // Desplegado, el globito está oculto.
    expect(globito().opacity, 0.0);

    // Tras el auto-colapso, aparece con el "2/7" visible.
    await tester.pump(const Duration(seconds: 17));
    await tester.pump(const Duration(milliseconds: 400));
    expect(globito().opacity, 1.0);
  });

  testWidgets(
    'Con lector de pantalla no se auto-minimiza y collapse() es no-op',
    (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              accessibleNavigation: true,
            ),
            child: Stack(
              children: [
                const SizedBox.expand(),
                TutorialCoachOverlay(
                  messages: const ['Elige tu hospital.'],
                  isDark: false,
                  onExit: () {},
                  step: 2,
                  totalSteps: 7,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      AnimatedOpacity bubbles() => tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('Elige tu hospital.'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );

      // Pasado de sobra el tiempo del auto-colapso, sigue desplegado.
      await tester.pump(const Duration(seconds: 17));
      await tester.pump(const Duration(milliseconds: 400));
      expect(bubbles().opacity, 1.0);

      // La minimización del host (tap/scroll en el contenido) tampoco aplica.
      tester
          .state<TutorialCoachOverlayState>(find.byType(TutorialCoachOverlay))
          .collapse();
      await tester.pump(const Duration(milliseconds: 400));
      expect(bubbles().opacity, 1.0);
    },
  );

  testWidgets('Las burbujas del paso son una live region para el lector', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Stack(
            children: [
              const SizedBox.expand(),
              TutorialCoachOverlay(
                messages: const ['Elige tu hospital.'],
                isDark: false,
                onExit: () {},
                step: 2,
                totalSteps: 7,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(
      tester.getSemantics(find.text('Elige tu hospital.')),
      isSemantics(isLiveRegion: true),
    );

    // Consume el timer del auto-colapso para cerrar el test sin pendientes.
    await tester.pump(const Duration(seconds: 17));
    handle.dispose();
  });

  /// Proporción NATIVA boina/alto de cada PNG, medida sobre los assets con
  /// `getbbox` + barrido de la banda superior (donde solo puede haber boina,
  /// nunca un brazo levantado). Se hornean aquí porque el test no debe abrir
  /// los PNG: lo que verifica es que el widget COMPENSE estas diferencias.
  ///
  /// `piensa` y `festeja` salieron de otra lámina de Gemini (240 px nativos
  /// reescalados a 520, contra ~700 px del resto), así que a igual altura de
  /// render su boina salía ~10% más grande y la instructora pegaba un salto de
}
