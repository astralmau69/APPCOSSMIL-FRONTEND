import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clip.dart';
import 'package:cossmil/core/animations/instructor/instructor_clips.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

InstructorRig _perfil() => InstructorRig.fromJson(<String, dynamic>{
  'canonicalHeight': 800.0,
  'aspect': 0.34,
  'pieces': [
    {
      'name': 'perfil_torso',
      'parent': null,
      'asset': 'pt.png',
      'pivot': [100.0, 500.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 10,
    },
    {
      'name': 'perfil_muslo_a',
      'parent': 'perfil_torso',
      'asset': 'pa.png',
      'pivot': [0.0, 5.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 9,
    },
    {
      'name': 'perfil_muslo_b',
      'parent': 'perfil_torso',
      'asset': 'pb.png',
      'pivot': [6.0, 5.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 7,
    },
    {
      'name': 'perfil_brazo',
      'parent': 'perfil_torso',
      'asset': 'pbr.png',
      'pivot': [2.0, -20.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 12,
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el ciclo cierra: el primer y el ultimo keyframe coinciden', () {
    for (final entrada in InstructorClips.walkCycle.tracks.entries) {
      final k = entrada.value;
      expect(
        k.first.rot,
        closeTo(k.last.rot, 1e-9),
        reason: '${entrada.key} no cierra el ciclo y daria un salto',
      );
    }
  });

  test('las dos piernas van en contrafase', () {
    final a = InstructorClips.walkCycle.tracks['perfil_muslo_a']!;
    final b = InstructorClips.walkCycle.tracks['perfil_muslo_b']!;
    final ta = sampleTrack(a, 0.25).rot;
    final tb = sampleTrack(b, 0.25).rot;
    expect(ta.sign, isNot(tb.sign), reason: 'las piernas se mueven juntas');
  });

  test('el brazo balancea contra la pierna', () {
    final pierna = sampleTrack(
      InstructorClips.walkCycle.tracks['perfil_muslo_a']!,
      0.25,
    ).rot;
    final brazo = sampleTrack(
      InstructorClips.walkCycle.tracks['perfil_brazo']!,
      0.25,
    ).rot;
    expect(pierna.sign, isNot(brazo.sign));
  });

  test('la cabeza no sube ni baja durante el ciclo', () {
    // En una caminata el craneo se queda quieto: si cabecea, la entrada parece
    // un salto de canguro.
    expect(InstructorClips.walkCycle.tracks.containsKey('cabeza'), isFalse);
    expect(
      InstructorClips.walkCycle.tracks.containsKey('perfil_torso'),
      isFalse,
    );
  });

  test('resuelve sobre el rig de perfil sin NaN', () {
    final rig = _perfil();
    for (var i = 0; i <= 12; i++) {
      final pose = solveInstructorPose(rig, [
        ClipLayer(clip: InstructorClips.walkCycle, t: i / 12),
      ]);
      expect(pose.length, 4);
      for (final m in pose.values) {
        for (final v in m.storage) {
          expect(v.isNaN, isFalse);
          expect(v.isFinite, isTrue);
        }
      }
    }
  });

  test('el manifest real trae el rig de perfil con sus seis piezas', () async {
    final rig = await loadInstructorRig();
    final perfil = rig.profile;
    expect(perfil, isNotNull, reason: 'el manifest no trae rig de perfil');
    final nombres = perfil!.bones.map((b) => b.name).toSet();
    for (final n in [
      'perfil_torso',
      'perfil_brazo',
      'perfil_muslo_a',
      'perfil_muslo_b',
      'perfil_pantorrilla_a',
      'perfil_pantorrilla_b',
    ]) {
      expect(nombres, contains(n));
    }
    // De perfil la figura es mucho mas angosta que de frente.
    expect(perfil.aspect, lessThan(rig.aspect));
  });

  test('todos los huesos del clip existen en el rig de perfil', () async {
    final perfil = (await loadInstructorRig()).profile!;
    final nombres = perfil.bones.map((b) => b.name).toSet();
    for (final hueso in InstructorClips.walkCycle.tracks.keys) {
      expect(
        nombres,
        contains(hueso),
        reason: 'el clip mueve "$hueso", que el rig de perfil no tiene',
      );
    }
  });

  Widget escena(Widget hijo) =>
      CupertinoApp(home: Center(child: hijo));

  /// El manifest carga en una fase aparte de los PNG: unos pocos pump bastan
  /// para tener pose sin decodificar texturas.
  ///
  /// El `runAsync` de entrada no es adorno: los tests de arriba ya pidieron el
  /// manifest, y `rootBundle` cachea el Future que creó AQUEL test, en su zona.
  /// Desde la zona fake-async de este no completaría nunca, así que la figura
  /// no llegaria a existir. Es artefacto de test: en la app hay una sola zona.
  Future<void> asentar(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  InstructorRigView vista(WidgetTester tester) =>
      tester.widget<InstructorRigView>(find.byType(InstructorRigView));

  test('un bloque de perfil roto no tumba el rig de frente', () {
    // Sin `aspect` el perfil no se puede dibujar. Eso cuesta la entrada
    // caminando; tumbar también el rig de frente costaría el tutorial entero.
    final rig = InstructorRig.fromJson(<String, dynamic>{
      'canonicalHeight': 800.0,
      'aspect': 0.63,
      'profile': {'pieces': []},
      'pieces': [
        {
          'name': 'torso',
          'parent': null,
          'asset': 't.png',
          'pivot': [0.0, 0.0],
          'anchor': [0.0, 0.0],
          'size': [10, 10],
          'z': 1,
        },
      ],
    });
    expect(rig.profile, isNull);
    expect(rig.bones.single.name, 'torso');
  });

  testWidgets('mientras entra caminando dibuja el rig de perfil', (
    tester,
  ) async {
    await tester.pumpWidget(
      escena(
        const TutorialInstructor(height: 200, entrance: true, walkIn: true),
      ),
    );
    await asentar(tester);
    final pose = vista(tester).pose;
    expect(
      pose.containsKey('perfil_torso'),
      isTrue,
      reason: 'entra de frente en vez de perfil',
    );
    expect(pose.containsKey('cabeza'), isFalse);
  });

  testWidgets('las piernas se mueven mientras camina', (tester) async {
    await tester.pumpWidget(
      escena(
        const TutorialInstructor(height: 200, entrance: true, walkIn: true),
      ),
    );
    await asentar(tester);
    final a = vista(tester).pose['perfil_muslo_a']!.clone();
    await tester.pump(const Duration(milliseconds: 220));
    final b = vista(tester).pose['perfil_muslo_a']!;
    expect(a == b, isFalse, reason: 'el muslo no se movio en 220 ms');
  });

  testWidgets('al llegar releva al rig de frente', (tester) async {
    await tester.pumpWidget(
      escena(
        const TutorialInstructor(height: 200, entrance: true, walkIn: true),
      ),
    );
    await asentar(tester);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 16));
    final pose = vista(tester).pose;
    expect(pose.containsKey('cabeza'), isTrue, reason: 'se quedo de perfil');
    expect(pose.containsKey('perfil_torso'), isFalse);
  });
}
