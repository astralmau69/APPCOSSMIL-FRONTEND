import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/animations/instructor/instructor_solver.dart';

Future<ui.Image> _punto() {
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(const [255, 0, 0, 255]),
    1,
    1,
    ui.PixelFormat.rgba8888,
    c.complete,
  );
  return c.future;
}

InstructorRig _rig() => InstructorRig.fromJson(<String, dynamic>{
  'canonicalHeight': 800.0,
  'aspect': 0.63,
  'pieces': [
    {
      'name': 'torso',
      'parent': null,
      'asset': 'torso.png',
      'pivot': [100.0, 400.0],
      'anchor': [50.0, 100.0],
      'size': [100, 200],
      'z': 10,
    },
    {
      'name': 'antena',
      'parent': 'torso',
      'asset': 'antena.png',
      'pivot': [10.0, -40.0],
      'anchor': [2.0, 30.0],
      'size': [6, 60],
      'z': 5,
    },
  ],
});

void main() {
  testWidgets('dibuja aunque falte una pieza', (tester) async {
    final rig = _rig();
    // Sólo el torso: 'antena.png' no cargó (archivo ausente o corrupto).
    final images = InstructorImages.forTest({
      'torso.png': (await tester.runAsync(_punto))!,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: InstructorRigView(
            rig: rig,
            images: images,
            pose: solveInstructorPose(rig, const []),
            height: 150,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(InstructorRigView), findsOneWidget);
  });

  testWidgets('no revienta con height 0', (tester) async {
    final rig = _rig();
    final images = InstructorImages.forTest({
      'torso.png': (await tester.runAsync(_punto))!,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: InstructorRigView(
            rig: rig,
            images: images,
            pose: solveInstructorPose(rig, const []),
            height: 0,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('no revienta con height negativo ni infinito', (tester) async {
    final rig = _rig();
    final images = InstructorImages.forTest({
      'torso.png': (await tester.runAsync(_punto))!,
    });
    for (final h in [-20.0, double.infinity, double.nan]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: InstructorRigView(
              rig: rig,
              images: images,
              pose: solveInstructorPose(rig, const []),
              height: h,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'height = $h');
    }
  });

  testWidgets('el ancho sale del aspect del rig, no de una constante', (
    tester,
  ) async {
    final rig = _rig();
    final images = InstructorImages.forTest({
      'torso.png': (await tester.runAsync(_punto))!,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: InstructorRigView(
            rig: rig,
            images: images,
            pose: solveInstructorPose(rig, const []),
            height: 200,
          ),
        ),
      ),
    );
    await tester.pump();
    final caja = tester.getSize(find.byType(InstructorRigView));
    expect(caja.height, 200);
    expect(caja.width, closeTo(200 * 0.63, 0.01));
  });

  test('shouldRepaint solo cuando cambia la pose o la escala', () {
    final rig = _rig();
    final a = solveInstructorPose(rig, const []);
    final p1 = InstructorRigPainter(
      rig: rig,
      images: const {},
      pose: a,
      scale: 1,
    );
    final p2 = InstructorRigPainter(
      rig: rig,
      images: const {},
      pose: a,
      scale: 1,
    );
    expect(p1.shouldRepaint(p2), isFalse);

    final p3 = InstructorRigPainter(
      rig: rig,
      images: const {},
      pose: Map.of(a),
      scale: 2,
    );
    expect(p1.shouldRepaint(p3), isTrue);
  });
}
