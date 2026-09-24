import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clips.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la secuencia de boca es determinista por voiceId', () {
    final a = mouthSequence(
      voiceId: 'ficha_01',
      duration: const Duration(seconds: 4),
    );
    final b = mouthSequence(
      voiceId: 'ficha_01',
      duration: const Duration(seconds: 4),
    );
    expect(a, b);
  });

  test('voiceId distinto da secuencia distinta', () {
    final a = mouthSequence(
      voiceId: 'ficha_01',
      duration: const Duration(seconds: 4),
    );
    final b = mouthSequence(
      voiceId: 'ficha_02',
      duration: const Duration(seconds: 4),
    );
    expect(a, isNot(b));
  });

  test('siempre cierra la boca al final', () {
    for (final id in ['ficha_01', 'ficha_07', 'calendario_00', 'guiado_dia']) {
      final s = mouthSequence(voiceId: id, duration: const Duration(seconds: 3));
      expect(s.last, 0, reason: '$id no cierra la boca');
    }
  });

  test('la longitud escala con la duracion y esta acotada', () {
    expect(
      mouthSequence(
        voiceId: 'x',
        duration: const Duration(milliseconds: 200),
      ).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      mouthSequence(voiceId: 'x', duration: const Duration(seconds: 60)).length,
      lessThanOrEqualTo(40),
    );
  });

  test('nunca repite la misma abertura dos veces seguidas', () {
    final s = mouthSequence(
      voiceId: 'ficha_03',
      duration: const Duration(seconds: 8),
    );
    for (var i = 1; i < s.length - 1; i++) {
      expect(s[i], isNot(s[i - 1]), reason: 'posicion $i');
    }
  });

  test('todas las aberturas son sprites de boca validos', () {
    final s = mouthSequence(
      voiceId: 'ficha_05',
      duration: const Duration(seconds: 6),
    );
    for (final v in s) {
      expect(v, inInclusiveRange(0, 5));
    }
  });

  testWidgets('mientras habla abre la boca; al callar la cierra', (
    tester,
  ) async {
    Widget escena(bool hablando) => CupertinoApp(
      home: Center(
        child: TutorialInstructor(
          height: 150,
          speaking: hablando,
          speakDuration: const Duration(seconds: 3),
        ),
      ),
    );

    await tester.pumpWidget(escena(true));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // En algun momento de la locucion la boca deja de ser la cerrada.
    var abrio = false;
    for (var i = 0; i < 40 && !abrio; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      final ocultos = tester
          .widget<InstructorRigView>(find.byType(InstructorRigView))
          .hidden;
      if (ocultos.contains('boca_0')) abrio = true;
    }
    expect(abrio, isTrue, reason: 'la boca nunca se abrio durante la locucion');

    await tester.pumpWidget(escena(false));
    await tester.pump(const Duration(milliseconds: 32));
    final ocultos = tester
        .widget<InstructorRigView>(find.byType(InstructorRigView))
        .hidden;
    expect(
      ocultos.contains('boca_0'),
      isFalse,
      reason: 'al callar la boca debe volver a la cerrada',
    );
  });

  testWidgets('cambiar de pose mientras habla no teletransporta la figura', (
    tester,
  ) async {
    Widget escena(InstructorPose p) => CupertinoApp(
      home: Center(
        child: TutorialInstructor(
          height: 150,
          pose: p,
          speaking: true,
          speakDuration: const Duration(seconds: 3),
        ),
      ),
    );

    await tester.pumpWidget(escena(InstructorPose.explica));
    await tester.pump(const Duration(milliseconds: 500));
    final antes = tester
        .widget<InstructorRigView>(find.byType(InstructorRigView))
        .pose['torso']!
        .getTranslation();

    await tester.pumpWidget(escena(InstructorPose.celebra));
    await tester.pump(const Duration(milliseconds: 16));
    final despues = tester
        .widget<InstructorRigView>(find.byType(InstructorRigView))
        .pose['torso']!
        .getTranslation();

    // Un fotograma despues el torso no puede haber saltado: _settle() deja
    // terminar el ciclo en curso en vez de cortar la fase.
    expect((despues.x - antes.x).abs(), lessThan(4.0));
    expect((despues.y - antes.y).abs(), lessThan(4.0));
  });
}
