import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clip.dart';
import 'package:cossmil/core/animations/instructor/instructor_clips.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

InstructorRig _rig() => InstructorRig.fromJson(<String, dynamic>{
  'canonicalHeight': 800.0,
  'aspect': 0.63,
  'pieces': [
    {
      'name': 'torso',
      'parent': null,
      'asset': 't.png',
      'pivot': [100.0, 400.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 10,
    },
    {
      'name': 'brazo_sup_der',
      'parent': 'torso',
      'asset': 'a.png',
      'pivot': [40.0, -60.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 8,
    },
    {
      'name': 'antebrazo_der',
      'parent': 'brazo_sup_der',
      'asset': 'b.png',
      'pivot': [0.0, 90.0],
      'anchor': [0.0, 0.0],
      'size': [10, 10],
      'z': 12,
    },
  ],
});

void main() {
  test('cada pose de gesto tiene su clip', () {
    for (final p in [
      InstructorPose.senala,
      InstructorPose.pulgarArriba,
      InstructorPose.alto,
      InstructorPose.sorpresa,
      InstructorPose.piensa,
      InstructorPose.celebra,
    ]) {
      expect(clipForPose(p), isNotNull, reason: 'falta el clip de $p');
    }
  });

  test('las poses sin gesto propio no fuerzan un clip', () {
    expect(clipForPose(InstructorPose.explica), isNull);
    expect(clipForPose(InstructorPose.reposo), isNull);
  });

  test('senalar tiene anticipacion: el brazo va al reves antes de ir', () {
    final keys = InstructorClips.senala.tracks['brazo_sup_der']!;
    expect(keys.length, greaterThanOrEqualTo(4));
    final destino = keys.last.rot;
    final anticipa = keys[1].rot;
    expect(
      anticipa.sign,
      isNot(destino.sign),
      reason: 'sin anticipacion el gesto arranca de la nada',
    );
  });

  test('senalar hace overshoot y se asienta', () {
    final keys = InstructorClips.senala.tracks['brazo_sup_der']!;
    final maxAbs = keys.map((k) => k.rot.abs()).reduce((a, b) => a > b ? a : b);
    expect(
      maxAbs,
      greaterThan(keys.last.rot.abs()),
      reason: 'el brazo debe pasarse del objetivo y volver',
    );
  });

  test('follow-through: el codo arranca despues que el hombro', () {
    final hombro = InstructorClips.senala.tracks['brazo_sup_der']!;
    final codo = InstructorClips.senala.tracks['antebrazo_der']!;
    expect(
      codo.first.t,
      greaterThan(hombro.first.t),
      reason: 'el codo tiene que llegar tarde',
    );
  });

  test('celebrar nunca mueve los dos brazos identicos', () {
    final der = InstructorClips.celebra.tracks['brazo_sup_der']!;
    final izq = InstructorClips.celebra.tracks['brazo_sup_izq']!;
    final mismosTiempos = der.length == izq.length &&
        List.generate(der.length, (i) => der[i].t == izq[i].t).every((x) => x);
    expect(
      mismosTiempos,
      isFalse,
      reason: 'la simetria perfecta es la marca del muneco',
    );
  });

  test('ningun gesto congela el torso: no declara ese hueso', () {
    for (final p in [
      InstructorPose.senala,
      InstructorPose.pulgarArriba,
      InstructorPose.alto,
      InstructorPose.sorpresa,
    ]) {
      expect(
        clipForPose(p)!.tracks.containsKey('torso'),
        isFalse,
        reason: '$p pisa el torso y cortaria la respiracion',
      );
    }
  });

  test('el gesto solo mueve los huesos que declara', () {
    final rig = _rig();
    final pose = solveInstructorPose(rig, [
      ClipLayer(clip: InstructorClips.senala, t: 0.5),
    ]);
    final t = pose['torso']!.getTranslation();
    expect(t.x, closeTo(100, 1e-9));
    expect(t.y, closeTo(400, 1e-9));
  });

  test('cada gesto mueve algo de verdad a mitad de camino', () {
    final rig = _rig();
    for (final p in [InstructorPose.senala, InstructorPose.pulgarArriba]) {
      final reposo = solveInstructorPose(rig, const []);
      final medio = solveInstructorPose(rig, [
        ClipLayer(clip: clipForPose(p)!, t: 0.5),
      ]);
      expect(
        medio['brazo_sup_der']!.storage,
        isNot(reposo['brazo_sup_der']!.storage),
        reason: '$p no mueve el brazo',
      );
    }
  });

  test('senala usa la mano de senalar', () {
    expect(instructorHandFor(InstructorPose.senala), 'mano_g_senala');
    expect(instructorHandFor(InstructorPose.pulgarArriba), 'mano_g_pulgar');
    expect(instructorHandFor(InstructorPose.alto), 'mano_g_abierta');
    expect(instructorHandFor(InstructorPose.explica), 'mano_der');
  });
}
