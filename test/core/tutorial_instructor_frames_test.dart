@Tags(['frames'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_instructor.dart';

/// Volcador de fotogramas de la instructora.
///
/// NO es un test de aserciones: es una herramienta de diagnóstico. Renderiza las
/// transiciones cuadro a cuadro y escribe cada frame como PNG, para poder MIRAR
/// y MEDIR la animación sin dispositivo y sin pasar por el login. Va detrás del
/// tag `frames` para que no corra en la suite normal:
///
///     flutter test --tags frames --run-skipped test/core/tutorial_instructor_frames_test.dart
///
/// Los PNG caen en `.dart_tool/instructor_frames` (ya ignorado por git).
void main() {
  final destino = Directory(
    Platform.environment['FRAME_DIR'] ?? '.dart_tool/instructor_frames',
  );
  final llave = GlobalKey();

  Widget escena(InstructorPose pose, {bool speaking = false}) => CupertinoApp(
    home: ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Center(
        child: RepaintBoundary(
          key: llave,
          child: SizedBox(
            width: 260,
            height: 320,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TutorialInstructor(
                height: 280,
                pose: pose,
                speaking: speaking,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Renderiza [pasos] fotogramas separados por [paso] y los guarda numerados.
  Future<void> volcar(
    WidgetTester tester,
    String etiqueta, {
    required int pasos,
    Duration paso = const Duration(milliseconds: 16),
  }) async {
    for (var i = 0; i < pasos; i++) {
      await tester.pump(paso);
      // toImage es asíncrono de verdad: hay que salir del reloj falso.
      await tester.runAsync(() async {
        final boundary =
            llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final imagen = await boundary.toImage();
        final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
        imagen.dispose();
        File('${destino.path}/$etiqueta-${i.toString().padLeft(3, '0')}.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(datos!.buffer.asUint8List());
      });
    }
  }

  /// La entrada caminando, que es la única animación que usa el rig de PERFIL.
  /// Sin dispositivo es el único modo de MIRAR si las piernas alternan, si la
  /// rodilla dobla hacia el lado correcto y si el brazo va en contrafase.
  /// Las poses con mano de GESTO. Son las que dependen del registro entre el
  /// sprite de la mano y el antebrazo del que cuelga, y eso no lo afirma
  /// ningun test: hay que verlo.
  testWidgets('vuelca las poses de gesto', (tester) async {
    await tester.runAsync(precacheInstructorRig);
    for (final pose in [
      InstructorPose.saludo,
      InstructorPose.senala,
      InstructorPose.alto,
      InstructorPose.pulgarArriba,
      InstructorPose.piensa,
      InstructorPose.celebra,
    ]) {
      await tester.pumpWidget(escena(pose));
      // 900 ms: el gesto mas largo (celebra) ya llego a su pose final.
      await volcar(
        tester,
        'g-${pose.name}',
        pasos: 2,
        paso: const Duration(milliseconds: 900),
      );
    }
    // ignore: avoid_print
    print('FOTOGRAMAS EN: ${destino.absolute.path}');
  });

  testWidgets('vuelca la caminata de entrada', (tester) async {
    await tester.runAsync(precacheInstructorRig);
    await tester.pumpWidget(
      CupertinoApp(
        home: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Center(
            child: RepaintBoundary(
              key: llave,
              child: const SizedBox(
                width: 260,
                height: 320,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TutorialInstructor(
                    height: 280,
                    entrance: true,
                    walkIn: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // 16 x 90 ms = 1440 ms: la zancada entera y el relevo a la pose de frente.
    await volcar(tester, 'w-camina', pasos: 16, paso: const Duration(milliseconds: 90));
    // ignore: avoid_print
    print('FOTOGRAMAS EN: ${destino.absolute.path}');
  });

  testWidgets('vuelca explica → piensa y la alternancia del festejo', (
    tester,
  ) async {
    // La precarga va ANTES de montar, y no es cosmético: al montar, el widget
    // pide el rig desde la zona fake-async y CACHEA ese Future. Precargar
    // después deja a `runAsync` esperando, desde la zona real, un Future que
    // sólo completa si alguien pumpea el reloj falso — y nadie lo hace hasta
    // que `runAsync` vuelva. Así se colgaba este volcador.
    await tester.runAsync(precacheInstructorRig);
    await tester.pumpWidget(escena(InstructorPose.explica));
    await tester.pump(const Duration(milliseconds: 32));

    await volcar(tester, 'a-explica', pasos: 3);

    await tester.pumpWidget(escena(InstructorPose.piensa));
    // 20 × 16 ms = 320 ms: cubre el golpe de squash (260) y la interpolación
    // del rig entre una pose y otra.
    await volcar(tester, 'b-a-piensa', pasos: 20);

    await tester.pumpWidget(escena(InstructorPose.celebra));
    await volcar(tester, 'c-a-celebra', pasos: 20);

    // ignore: avoid_print
    print('FOTOGRAMAS EN: ${destino.absolute.path}');
  });
}
