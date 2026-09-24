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
///     flutter test --tags frames test/core/tutorial_instructor_frames_test.dart
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

  testWidgets('vuelca explica → piensa y la alternancia del festejo', (
    tester,
  ) async {
    await tester.pumpWidget(escena(InstructorPose.explica));
    // Las piezas del rig se decodifican fuera del reloj falso; sin esto se
    // pintan vacías.
    await tester.runAsync(precacheInstructorRig);
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
