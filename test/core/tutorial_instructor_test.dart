import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

/// Tests de la INSTRUCTORA. Los del coach viven en
/// `tutorial_coach_overlay_test.dart`.
///
/// Reescritos al pasar de un juego de PNG de cuerpo entero a un rig de
/// recortes: ya no hay "asset visible" que interrogar, sino una pose de huesos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget escena(Widget hijo, {bool reduceMotion = false}) => CupertinoApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(child: hijo),
    ),
  );

  /// El manifest carga en una fase aparte de los PNG: unos pocos pump bastan
  /// para tener pose sin decodificar texturas.
  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  InstructorRigView vista(WidgetTester tester) =>
      tester.widget<InstructorRigView>(find.byType(InstructorRigView));

  testWidgets('renderiza el rig del personaje', (tester) async {
    await tester.pumpWidget(escena(const TutorialInstructor(height: 80)));
    await asentar(tester);
    expect(find.byType(InstructorRigView), findsOneWidget);
    // El rig trae el cuerpo entero, no una lámina.
    final pose = vista(tester).pose;
    for (final hueso in ['torso', 'cabeza', 'antena', 'muslo_izq']) {
      expect(pose.containsKey(hueso), isTrue, reason: 'falta el hueso $hueso');
    }
  });

  testWidgets('dibuja un solo juego de ojos a la vez', (tester) async {
    await tester.pumpWidget(escena(const TutorialInstructor(height: 200)));
    await asentar(tester);
    final ocultos = vista(tester).hidden;
    const todos = [
      'ojos_abiertos',
      'ojos_medio',
      'ojos_cerrados',
      'ojos_guino',
      'ojos_feliz',
      'ojos_sorpresa',
    ];
    final visibles = todos.where((o) => !ocultos.contains(o)).toList();
    expect(visibles, hasLength(1));
  });

  testWidgets('dibuja una sola boca a la vez', (tester) async {
    await tester.pumpWidget(escena(const TutorialInstructor(height: 200)));
    await asentar(tester);
    final ocultos = vista(tester).hidden;
    final visibles = [
      for (var i = 0; i < 6; i++) 'boca_$i',
    ].where((b) => !ocultos.contains(b)).toList();
    expect(visibles, hasLength(1));
  });

  testWidgets('en piensa cierra los ojos', (tester) async {
    await tester.pumpWidget(
      escena(
        const TutorialInstructor(height: 200, pose: InstructorPose.piensa),
      ),
    );
    await asentar(tester);
    expect(vista(tester).hidden.contains('ojos_cerrados'), isFalse);
  });

  testWidgets('al celebrar pone los ojos felices', (tester) async {
    await tester.pumpWidget(
      escena(
        const TutorialInstructor(height: 200, pose: InstructorPose.celebra),
      ),
    );
    await asentar(tester);
    expect(vista(tester).hidden.contains('ojos_feliz'), isFalse);
  });

  testWidgets('walkIn con reduce-motion: aparece parada, sin caminar', (
    tester,
  ) async {
    await tester.pumpWidget(
      escena(
        const TutorialInstructor(
          height: 200,
          pose: InstructorPose.explica,
          entrance: true,
          walkIn: true,
        ),
        reduceMotion: true,
      ),
    );
    await asentar(tester);
    // Sin caminata: ya está en su sitio, sin desplazamiento horizontal.
    expect(find.byType(InstructorRigView), findsOneWidget);
    final caja = tester.getRect(find.byType(InstructorRigView));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(find.byType(InstructorRigView)), caja);
  });

  /// Regresión del bug histórico del set anterior.
  ///
  /// `piensa` y `festeja` salían de otra lámina (240 px nativos reescalados a
  /// 520, contra ~700 px del resto), así que a igual altura de render su boina
  /// quedaba ~10% más grande y la instructora pegaba un SALTO DE TAMAÑO en cada
  /// cambio de pose — y `explica → piensa` ocurre entre cada par de burbujas.
  ///
  /// Con un rig el fallo es imposible por construcción: hay UNA sola pieza de
  /// cabeza para todas las poses. El test se conserva como guardia: si algún
  /// día alguien vuelve a meter cabezas por pose, salta aquí.
  testWidgets('la cabeza mide lo mismo en todas las poses', (tester) async {
    const alto = 200.0;
    final tamanos = <InstructorPose, Size>{};

    for (final pose in InstructorPose.values) {
      await tester.pumpWidget(
        escena(TutorialInstructor(height: alto, pose: pose)),
      );
      await asentar(tester);
      final hueso = vista(tester).rig.byName('cabeza');
      expect(hueso, isNotNull, reason: 'el rig no trae pieza de cabeza');
      tamanos[pose] = hueso!.size;
    }

    final ref = tamanos[InstructorPose.explica]!;
    for (final e in tamanos.entries) {
      expect(
        e.value,
        ref,
        reason:
            '${e.key.name}: la cabeza mide ${e.value} contra $ref de explica. '
            'Con un rig debe ser la MISMA pieza en todas las poses.',
      );
    }
  });
}
