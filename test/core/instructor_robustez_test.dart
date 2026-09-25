import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/widgets/tutorial_coach_overlay.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

/// Un bundle que no sirve ningún asset: modela el manifest ausente o ilegible.
class _BundleRoto extends AssetBundle {
  @override
  Future<ByteData> load(String key) async => throw FlutterError('sin $key');

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw FlutterError('sin $key');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la precarga del rig nunca propaga', (tester) async {
    // Inicio marca el tutorial como "visto" ANTES de abrir la invitación, y
    // espera esta precarga. Si propagara, la invitación no volvería nunca.
    await tester.runAsync(() async {
      await expectLater(
        precacheInstructorRig(bundle: _BundleRoto()),
        completes,
      );
      // Y el fallo no queda cacheado: el siguiente intento, con el bundle real,
      // tiene que funcionar.
      await precacheInstructorRig();
    });
    expect(TutorialInstructor.aspecto, greaterThan(0.3));
  });

  testWidgets('el coach le pasa el voiceId a la instructora', (tester) async {
    // Es la semilla del movimiento de boca: sin ella dos pasos con locuciones
    // de la misma duración mueven los labios idéntico.
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Stack(
            children: [
              const SizedBox.expand(),
              TutorialCoachOverlay(
                messages: const ['Hola'],
                isDark: false,
                onExit: () {},
                voiceId: 'ficha_01',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    final figura = tester.widget<TutorialInstructor>(
      find.byType(TutorialInstructor),
    );
    expect(figura.voiceId, 'ficha_01');
  });
}
