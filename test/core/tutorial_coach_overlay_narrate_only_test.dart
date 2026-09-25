import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';

/// `narrateOnly` es el coach sobre una reserva REAL (Modo Guiado). No cambia
/// cómo narra; cambia lo que el coach DICE DE SÍ MISMO — porque anunciar "modo
/// entrenamiento" u ofrecer "salir del tutorial" sobre una cita que sí se va a
/// registrar hace que el usuario no sepa qué está haciendo.
void main() {
  Widget escena(TutorialCoachOverlay coach) => CupertinoApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Stack(children: [const SizedBox.expand(), coach]),
    ),
  );

  test('narrateOnly es false por defecto y se acepta como parámetro', () {
    final normal = TutorialCoachOverlay(
      messages: const ['Hola'],
      isDark: false,
      onExit: () {},
    );
    expect(normal.narrateOnly, isFalse);

    final guiado = TutorialCoachOverlay(
      messages: const ['Hola'],
      isDark: false,
      onExit: () {},
      narrateOnly: true,
    );
    expect(guiado.narrateOnly, isTrue);
  });

  testWidgets('la insignia no dice ENTRENAMIENTO sobre una reserva real', (
    tester,
  ) async {
    await tester.pumpWidget(
      escena(
        TutorialCoachOverlay(
          messages: const ['Elija el hospital.'],
          isDark: false,
          onExit: () {},
          step: 1,
          totalSteps: 7,
          narrateOnly: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('RESERVA GUIADA · PASO 1/7'), findsOneWidget);
    expect(find.textContaining('ENTRENAMIENTO'), findsNothing);
  });

  testWidgets('el botón de cerrar ofrece ocultar la guía, no salir del tutorial', (
    tester,
  ) async {
    await tester.pumpWidget(
      escena(
        TutorialCoachOverlay(
          messages: const ['Elija el hospital.'],
          isDark: false,
          onExit: () {},
          step: 1,
          totalSteps: 7,
          narrateOnly: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.bySemanticsLabel('Ocultar la guía'),
      findsOneWidget,
      reason: 'sobre una reserva real no se "sale del tutorial"',
    );
  });

  testWidgets('la confirmación guiada no habla de abandonar el tutorial', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    confirmExitTutorial(ctx, guiado: true);
    await tester.pumpAndSettle();

    expect(find.text('¿Ocultar la guía?'), findsOneWidget);
    expect(find.textContaining('reserva sigue'), findsOneWidget);
    expect(find.textContaining('Salir del tutorial'), findsNothing);
  });
}
