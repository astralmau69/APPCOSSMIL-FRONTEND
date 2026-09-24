import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig.dart';

void main() {
  const json = <String, dynamic>{
    'canonicalHeight': 800.0,
    'aspect': 0.63,
    'pieces': [
      {
        'name': 'torso',
        'parent': null,
        'asset': 'torso.png',
        'pivot': [0.0, 0.0],
        'anchor': [10.0, 20.0],
        'size': [30, 40],
        'z': 10,
      },
      {
        'name': 'cabeza',
        'parent': 'torso',
        'asset': 'cabeza.png',
        'pivot': [0.0, -50.0],
        'anchor': [5.0, 8.0],
        'size': [12, 16],
        'z': 20,
      },
    ],
  };

  test('parsea el manifest', () {
    final rig = InstructorRig.fromJson(json);
    expect(rig.canonicalHeight, 800.0);
    expect(rig.aspect, 0.63);
    expect(rig.bones.length, 2);
    expect(rig.byName('cabeza')!.parent, 'torso');
    expect(rig.byName('cabeza')!.pivot, const Offset(0, -50));
    expect(rig.byName('cabeza')!.asset, 'cabeza.png');
    expect(rig.byName('torso')!.size, const Size(30, 40));
    expect(rig.byName('torso')!.anchor, const Offset(10, 20));
    expect(rig.byName('no_existe'), isNull);
  });

  test('drawOrder ordena por z ascendente', () {
    final rig = InstructorRig.fromJson(json);
    expect(rig.drawOrder.map((b) => b.name).toList(), ['torso', 'cabeza']);
  });

  test('drawOrder no depende del orden del JSON', () {
    final invertido = <String, dynamic>{
      ...json,
      'pieces': (json['pieces'] as List).reversed.toList(),
    };
    final rig = InstructorRig.fromJson(invertido);
    expect(rig.drawOrder.map((b) => b.name).toList(), ['torso', 'cabeza']);
  });

  test('rechaza un padre inexistente', () {
    expect(
      () => InstructorRig.fromJson(<String, dynamic>{
        'canonicalHeight': 800.0,
        'aspect': 0.63,
        'pieces': [
          {
            'name': 'mano',
            'parent': 'fantasma',
            'asset': 'm.png',
            'pivot': [0.0, 0.0],
            'anchor': [0.0, 0.0],
            'size': [1, 1],
            'z': 1,
          },
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('rechaza un ciclo en la jerarquia', () {
    expect(
      () => InstructorRig.fromJson(<String, dynamic>{
        'canonicalHeight': 800.0,
        'aspect': 0.63,
        'pieces': [
          {
            'name': 'a',
            'parent': 'b',
            'asset': 'a.png',
            'pivot': [0.0, 0.0],
            'anchor': [0.0, 0.0],
            'size': [1, 1],
            'z': 1,
          },
          {
            'name': 'b',
            'parent': 'a',
            'asset': 'b.png',
            'pivot': [0.0, 0.0],
            'anchor': [0.0, 0.0],
            'size': [1, 1],
            'z': 2,
          },
        ],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('tolera claves extra del manifest real', () {
    // El manifest trae `coverage`, `profile` y `wrist`, que este modelo ignora.
    final rig = InstructorRig.fromJson(<String, dynamic>{
      ...json,
      'coverage': {'cubierto': 99.7},
      'profile': {'pieces': []},
      'pieces': [
        {...(json['pieces'] as List).first as Map<String, dynamic>, 'wrist': 42},
      ],
    });
    expect(rig.bones.single.name, 'torso');
  });
}
