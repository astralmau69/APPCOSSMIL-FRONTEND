import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  testWidgets('TutorialInstructor renderiza el asset del personaje', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(child: TutorialInstructor(height: 80)),
      ),
    );
    // Un frame extra para el bucle de animación (sin settle: es infinito).
    await tester.pump(const Duration(milliseconds: 300));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, kTutorialInstructorAsset);
  });

  testWidgets('TutorialCoachOverlay muestra instructora, insignia y burbujas',
      (tester) async {
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
    // Deja pasar el pop escalonado de las burbujas (delay máx ~320 ms + anim).
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(TutorialInstructor), findsOneWidget);
    expect(find.text('MODO ENTRENAMIENTO · PASO 1/6'), findsOneWidget);
    expect(find.text('¡Hola! Vamos a sacar tu primera ficha juntos.'), findsOneWidget);
    expect(find.text('Primero elige tu hospital o policlínico.'), findsOneWidget);

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
}
