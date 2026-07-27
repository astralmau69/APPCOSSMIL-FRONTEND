import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/services/tutorial_flow.dart';
import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';
import 'package:cossmil/core/widgets/tutorial_flow_host.dart';

Widget _harness(Widget child) => CupertinoApp(
  home: MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: child,
  ),
);

void main() {
  tearDown(TutorialFlow.stop);

  testWidgets('solo muestra el coach cuando SU tutorial está activo', (
    tester,
  ) async {
    var flagSeen = false;
    await tester.pumpWidget(
      _harness(
        TutorialFlowHost(
          tutorial: GuidedTutorial.calendario,
          messages: const ['Elige tu hospital.'],
          step: 1,
          totalSteps: 4,
          builder: (context, on) {
            flagSeen = on;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    expect(find.byType(TutorialCoachOverlay), findsNothing);
    expect(flagSeen, isFalse);

    // Otro tutorial activo: esta pantalla sigue sin coach.
    TutorialFlow.start(GuidedTutorial.tramites);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TutorialCoachOverlay), findsNothing);

    // El suyo: coach visible, burbujas del paso y flag para GuidedTapHint.
    TutorialFlow.start(GuidedTutorial.calendario);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(TutorialCoachOverlay), findsOneWidget);
    expect(find.text('Elige tu hospital.'), findsOneWidget);
    expect(flagSeen, isTrue);

    // Al apagarse, el coach desaparece del árbol.
    await tester.pump(const Duration(seconds: 17));
    TutorialFlow.stop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TutorialCoachOverlay), findsNothing);
  });

  testWidgets('en el paso final, salir no pide confirmación y apaga todo', (
    tester,
  ) async {
    TutorialFlow.start(GuidedTutorial.tramites);
    await tester.pumpWidget(
      _harness(
        TutorialFlowHost(
          tutorial: GuidedTutorial.tramites,
          messages: const ['¡Listo!'],
          step: 4,
          totalSteps: 4,
          celebrate: true,
          confirmOnExit: false,
          builder: (context, _) => const SizedBox.expand(),
        ),
      ),
    );
    // Dos pumps: el primero dispara los timers del pop escalonado, el
    // segundo avanza de verdad la animación (el primer tick de un
    // AnimationController en fake-async reporta elapsed 0).
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pump(const Duration(milliseconds: 400));

    expect(TutorialFlow.active.value, GuidedTutorial.none);
    expect(find.byType(TutorialCoachOverlay), findsNothing);
    // No debe haber quedado abierta ninguna hoja de confirmación.
    expect(find.text('¿Salir del tutorial?'), findsNothing);
  });

  testWidgets('stopOnDispose cancela el tutorial al desmontar la raíz', (
    tester,
  ) async {
    TutorialFlow.start(GuidedTutorial.tramites);
    await tester.pumpWidget(
      _harness(
        TutorialFlowHost(
          tutorial: GuidedTutorial.tramites,
          messages: const ['Entra a Gerencia de Salud.'],
          step: 1,
          totalSteps: 4,
          stopOnDispose: true,
          builder: (context, _) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));

    await tester.pumpWidget(_harness(const SizedBox()));
    await tester.pump();

    expect(TutorialFlow.active.value, GuidedTutorial.none);
  });
}
