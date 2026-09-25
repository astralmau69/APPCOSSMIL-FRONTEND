import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  Widget scene(
    InstructorPose pose, {
    bool idle = false,
    bool reduced = false,
  }) => CupertinoApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TutorialInstructor(height: 200, pose: pose, idle: idle),
    ),
  );

  Map<String, List<double>> snapshot(WidgetTester tester) => {
    for (final entry
        in tester
            .widget<InstructorRigView>(find.byType(InstructorRigView))
            .pose
            .entries)
      entry.key: entry.value.storage.toList(),
  };

  void unchanged(
    Map<String, List<double>> before,
    Map<String, List<double>> after,
  ) {
    for (final bone in before.keys) {
      for (var i = 0; i < 16; i++) {
        expect(
          after[bone]![i],
          closeTo(before[bone]![i], 1e-8),
          reason: '$bone matrix[$i] jumped on pose change',
        );
      }
    }
  }

  for (final idle in [false, true]) {
    for (final target in [InstructorPose.alto, InstructorPose.reposo]) {
      testWidgets('interrupted blend remains continuous: idle=$idle, $target', (
        tester,
      ) async {
        await tester.pumpWidget(scene(InstructorPose.piensa, idle: idle));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpWidget(scene(InstructorPose.senala, idle: idle));
        await tester.pump(const Duration(milliseconds: 220));
        final before = snapshot(tester);
        await tester.pumpWidget(scene(target, idle: idle));
        unchanged(before, snapshot(tester));
        await tester.pump(const Duration(seconds: 2));
        if (!idle) {
          final settled = snapshot(tester);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(scene(target));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          unchanged(snapshot(tester), settled);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('poses sharing a gesture preserve the settled pose', (
    tester,
  ) async {
    await tester.pumpWidget(scene(InstructorPose.celebra));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = snapshot(tester);
    await tester.pumpWidget(scene(InstructorPose.festeja));
    unchanged(before, snapshot(tester));
  });

  testWidgets('reduced motion switches immediately and remains stationary', (
    tester,
  ) async {
    await tester.pumpWidget(scene(InstructorPose.piensa, reduced: true));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final before = snapshot(tester);
    await tester.pumpWidget(scene(InstructorPose.alto, reduced: true));
    final after = snapshot(tester);
    expect(after['antebrazo_der'], isNot(before['antebrazo_der']));
    await tester.pump(const Duration(seconds: 2));
    unchanged(after, snapshot(tester));
  });
}
