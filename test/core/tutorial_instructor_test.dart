import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  testWidgets('TutorialInstructor renderiza el asset del personaje', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(home: Center(child: TutorialInstructor(height: 80))),
    );
    // Un frame extra para el bucle de animación (sin settle: es infinito).
    await tester.pump(const Duration(milliseconds: 300));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, kTutorialInstructorAsset);
  });

  /// Asset que la instructora está mostrando ahora mismo. Ya no hay fundido
  /// (los relevos son cortes secos), así que siempre hay un solo Image.
  String poseVisible(WidgetTester tester) {
    final imagenes = tester.widgetList<Image>(
      find.descendant(
        of: find.byType(TutorialInstructor),
        matching: find.byType(Image),
      ),
    );
    return (imagenes.last.image as AssetImage).assetName;
  }

  testWidgets('walkIn: entra caminando y al llegar adopta la pose', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: TutorialInstructor(
            height: 200,
            pose: InstructorPose.explica,
            entrance: true,
            walkIn: true,
          ),
        ),
      ),
    );

    // Durante la caminata (~1.3 s) se ven fotogramas del ciclo.
    await tester.pump(const Duration(milliseconds: 400));
    expect(poseVisible(tester), contains('instructora_walk_'));

    // Al llegar a su sitio, releva a la pose real.
    await tester.pump(const Duration(milliseconds: 1300));
    expect(poseVisible(tester), contains('instructora_explica'));
  });

  testWidgets('walkIn con reduce-motion: aparece parada, sin caminar', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Center(
              child: TutorialInstructor(
                height: 200,
                pose: InstructorPose.explica,
                entrance: true,
                walkIn: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(poseVisible(tester), contains('instructora_explica'));
  });

  testWidgets('la instructora cambia de pose: explica, descansa y celebra', (
    tester,
  ) async {
    Widget coach({required bool celebrate}) => CupertinoApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Stack(
          children: [
            const SizedBox.expand(),
            TutorialCoachOverlay(
              messages: const ['Elige tu hospital.'],
              isDark: false,
              onExit: () {},
              celebrate: celebrate,
              step: 2,
              totalSteps: 7,
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(coach(celebrate: false));
    // Primero entra caminando (~1.3 s): al inicio se ven fotogramas del ciclo.
    await tester.pump(const Duration(milliseconds: 500));
    expect(poseVisible(tester), contains('instructora_walk_'));
    // Ya en su sitio, adopta la pose y da instrucciones: señala la tablet.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(poseVisible(tester), contains('instructora_explica'));

    // Tras el auto-colapso baja la tablet y descansa.
    await tester.pump(const Duration(seconds: 17));
    await tester.pump(const Duration(milliseconds: 400));
    expect(poseVisible(tester), contains('instructora_reposo'));

    // Celebrar manda sobre todo lo demás.
    await tester.pumpWidget(coach(celebrate: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(poseVisible(tester), contains('instructora_celebra'));

    // Consume el temporizador pendiente para cerrar limpio.
    await tester.pump(const Duration(seconds: 17));
  });

  testWidgets('pose piensa se renderiza', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: TutorialInstructor(height: 200, pose: InstructorPose.piensa),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(poseVisible(tester), contains('instructora_piensa'));
  });

  testWidgets('paso regular con locución NO festeja: se queda en explica', (
    tester,
  ) async {
    // Pose neutral (explica) hablando: nunca alterna check/risa — el festejo
    // está reservado al paso de éxito (tono profesional).
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: TutorialInstructor(
            height: 200,
            pose: InstructorPose.explica,
            speaking: true,
            speakDuration: Duration(seconds: 5),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(poseVisible(tester), contains('instructora_explica'));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(poseVisible(tester), contains('instructora_explica'));
  });

  testWidgets(
    'paso de éxito: festeja sincronizado con la locución; al callar vuelve al reposo',
    (tester) async {
      Widget w({required bool speaking, Duration? d}) => CupertinoApp(
        home: Center(
          child: TutorialInstructor(
            height: 200,
            pose: InstructorPose.celebra, // paso de éxito
            speaking: speaking,
            speakDuration: d,
          ),
        ),
      );

      // Con locución de 5 s: alterna check (celebra) → risa (festeja) a lo
      // largo del audio.
      await tester.pumpWidget(w(speaking: true, d: const Duration(seconds: 5)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(poseVisible(tester), contains('instructora_celebra'));
      await tester.pump(const Duration(milliseconds: 1150));
      // El dibujo NO se releva en el instante del cruce: se sigue pintando el
      // saliente mientras el golpe comprime, y el cambio es un corte seco en el
      // pico (~83 ms después). Un frame más para pasar el corte.
      expect(poseVisible(tester), contains('instructora_celebra'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(poseVisible(tester), contains('instructora_festeja'));

      // El audio termina (speaking=false): NO sigue festejando en bucle; queda
      // en su pose de éxito (check estático). Invariante de reposo.
      await tester.pumpWidget(w(speaking: false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(poseVisible(tester), contains('instructora_celebra'));
    },
  );

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
  /// tamaño en cada cambio de pose.
  const boinaNativa = {
    InstructorPose.explica: 0.5600,
    InstructorPose.reposo: 0.5600,
    InstructorPose.celebra: 0.5586,
    InstructorPose.saludo: 0.5557,
    InstructorPose.piensa: 0.6115,
    InstructorPose.festeja: 0.6173,
  };

  testWidgets('la boina mide lo mismo en todas las poses', (tester) async {
    const alto = 200.0;
    final efectiva = <InstructorPose, double>{};

    for (final pose in boinaNativa.keys) {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: TutorialInstructor(height: alto, pose: pose),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final img = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byType(TutorialInstructor),
              matching: find.byType(Image),
            ),
          )
          .last;
      // Tamaño con el que la boina acaba dibujándose en pantalla.
      efectiva[pose] = img.height! * boinaNativa[pose]!;
    }

    final ref = efectiva[InstructorPose.explica]!;
    for (final entrada in efectiva.entries) {
      final desvio = (entrada.value / ref - 1).abs();
      expect(
        desvio,
        lessThan(0.02),
        reason:
            '${entrada.key.name}: la boina se dibuja a ${entrada.value.toStringAsFixed(1)} px '
            'contra ${ref.toStringAsFixed(1)} px de explica '
            '(${(desvio * 100).toStringAsFixed(1)}% de desvío). Sin la corrección '
            'de _kPoseScale, piensa y festeja se van por encima del 9%.',
      );
    }
  });
}
