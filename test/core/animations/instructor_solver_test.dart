import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_clip.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';

InstructorRig _rig() => InstructorRig.fromJson(<String, dynamic>{
  'canonicalHeight': 800.0,
  'aspect': 0.63,
  'pieces': [
    {
      'name': 'torso',
      'parent': null,
      'asset': 't.png',
      'pivot': [100.0, 400.0],
      'anchor': [50.0, 100.0],
      'size': [100, 200],
      'z': 10,
    },
    {
      'name': 'brazo',
      'parent': 'torso',
      'asset': 'b.png',
      'pivot': [40.0, -60.0],
      'anchor': [10.0, 10.0],
      'size': [30, 120],
      'z': 12,
    },
  ],
});

/// Ángulo de rotación que lleva una matriz de pose.
double _rot(Matrix4 m) => math.atan2(m.row1.x, m.row0.x);

void main() {
  test('sampleTrack interpola entre keyframes', () {
    const keys = [
      BoneKey(t: 0, rot: 0),
      BoneKey(t: 1, rot: math.pi / 2, curve: Curves.linear),
    ];
    expect(sampleTrack(keys, 0).rot, 0);
    expect(sampleTrack(keys, 0.5).rot, closeTo(math.pi / 4, 1e-9));
    expect(sampleTrack(keys, 1).rot, closeTo(math.pi / 2, 1e-9));
  });

  test('sampleTrack fuera de rango devuelve los extremos', () {
    const keys = [BoneKey(t: 0.2, rot: 1), BoneKey(t: 0.8, rot: 3)];
    expect(sampleTrack(keys, 0).rot, 1);
    expect(sampleTrack(keys, 1).rot, 3);
  });

  test('sampleTrack con la pista vacia devuelve la identidad', () {
    expect(sampleTrack(const [], 0.5).rot, 0);
    expect(sampleTrack(const [], 0.5).scale, 1);
    expect(sampleTrack(const [], 0.5).translate, Offset.zero);
  });

  test('sampleTrack aplica la curva del keyframe de destino', () {
    const keys = [
      BoneKey(t: 0, rot: 0),
      BoneKey(t: 1, rot: 1, curve: Curves.easeIn),
    ];
    // easeIn arranca lento: a mitad de camino lleva menos de la mitad.
    expect(sampleTrack(keys, 0.5).rot, lessThan(0.5));
  });

  test('una lista vacia de capas da la pose de reposo', () {
    final pose = solveInstructorPose(_rig(), const []);
    final t = pose['torso']!.getTranslation();
    expect(t.x, closeTo(100, 1e-9));
    expect(t.y, closeTo(400, 1e-9));
    // el brazo hereda el pivote del torso
    final b = pose['brazo']!.getTranslation();
    expect(b.x, closeTo(140, 1e-9));
    expect(b.y, closeTo(340, 1e-9));
  });

  test('las capas son aditivas y se ponderan', () {
    final rig = _rig();
    const c1 = InstructorClip(
      name: 'a',
      duration: Duration(seconds: 1),
      tracks: {
        'brazo': [BoneKey(t: 0, rot: 1.0), BoneKey(t: 1, rot: 1.0)],
      },
    );
    const c2 = InstructorClip(
      name: 'b',
      duration: Duration(seconds: 1),
      tracks: {
        'brazo': [BoneKey(t: 0, rot: 2.0), BoneKey(t: 1, rot: 2.0)],
      },
    );
    final pose = solveInstructorPose(rig, const [
      ClipLayer(clip: c1, t: 0.5),
      ClipLayer(clip: c2, t: 0.5, weight: 0.5),
    ]);
    expect(_rot(pose['brazo']!), closeTo(2.0, 1e-6));
  });

  test('un hueso que ninguna capa toca no se mueve', () {
    final rig = _rig();
    const clip = InstructorClip(
      name: 'solo_brazo',
      duration: Duration(seconds: 1),
      tracks: {
        'brazo': [BoneKey(t: 0, rot: 0.9), BoneKey(t: 1, rot: 0.9)],
      },
    );
    final pose = solveInstructorPose(rig, const [ClipLayer(clip: clip, t: 0.3)]);
    expect(_rot(pose['torso']!), closeTo(0, 1e-9));
  });

  test('el hijo hereda la rotacion del padre', () {
    final rig = _rig();
    const clip = InstructorClip(
      name: 'gira_torso',
      duration: Duration(seconds: 1),
      tracks: {
        'torso': [BoneKey(t: 0, rot: 0.5), BoneKey(t: 1, rot: 0.5)],
      },
    );
    final pose = solveInstructorPose(rig, const [ClipLayer(clip: clip, t: 0.5)]);
    expect(_rot(pose['brazo']!), closeTo(0.5, 1e-9));
    // y su posicion deja de ser la de reposo
    expect(pose['brazo']!.getTranslation().x, isNot(closeTo(140, 1e-3)));
  });

  test('ninguna matriz trae NaN a lo largo del clip', () {
    final rig = _rig();
    const clip = InstructorClip(
      name: 'x',
      duration: Duration(seconds: 1),
      tracks: {
        'torso': [BoneKey(t: 0, scale: 1.0), BoneKey(t: 1, scale: 1.2)],
      },
    );
    for (var i = 0; i <= 10; i++) {
      final pose = solveInstructorPose(rig, [
        ClipLayer(clip: clip, t: i / 10),
      ]);
      for (final m in pose.values) {
        for (final v in m.storage) {
          expect(v.isNaN, isFalse);
          expect(v.isFinite, isTrue);
        }
      }
    }
  });

  test('devuelve una matriz por hueso', () {
    final pose = solveInstructorPose(_rig(), const []);
    expect(pose.keys.toSet(), {'torso', 'brazo'});
  });
}
