import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/instructor/instructor_rig_view.dart';
import 'package:cossmil/core/widgets/tutorial_instructor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child, {bool reduceMotion = false}) => CupertinoApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Center(child: child),
    ),
  );

  /// El manifest se carga en una fase aparte de las imagenes, asi que unos
  /// pocos pump alcanzan para tener rig (y por tanto pose) sin decodificar PNG.
  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Map<String, Matrix4> poseDe(WidgetTester tester) =>
      tester.widget<InstructorRigView>(find.byType(InstructorRigView)).pose;

  testWidgets('renderiza el rig, no un Image de cuerpo entero', (tester) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await asentar(tester);
    expect(find.byType(InstructorRigView), findsOneWidget);
  });

  testWidgets('con reduce-motion queda estatica', (tester) async {
    await tester.pumpWidget(
      host(const TutorialInstructor(height: 150), reduceMotion: true),
    );
    await asentar(tester);
    final a = poseDe(tester);
    final antes = {for (final e in a.entries) e.key: [...e.value.storage]};
    await tester.pump(const Duration(milliseconds: 900));
    final b = poseDe(tester);
    for (final k in antes.keys) {
      expect(
        b[k]!.storage,
        antes[k],
        reason: 'el hueso "$k" se movio con reduce-motion activo',
      );
    }
  });

  testWidgets('sin reduce-motion el idle mueve el torso', (tester) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await asentar(tester);
    final antes = [...poseDe(tester)['torso']!.storage];
    await tester.pump(const Duration(milliseconds: 650));
    expect(poseDe(tester)['torso']!.storage, isNot(antes));
  });

  testWidgets('el idle tambien mueve la antena (movimiento secundario)', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await asentar(tester);
    final antes = [...poseDe(tester)['antena']!.storage];
    await tester.pump(const Duration(milliseconds: 800));
    expect(poseDe(tester)['antena']!.storage, isNot(antes));
  });

  testWidgets('con idle:false el torso no respira', (tester) async {
    await tester.pumpWidget(
      host(const TutorialInstructor(height: 150, idle: false)),
    );
    await asentar(tester);
    final antes = [...poseDe(tester)['torso']!.storage];
    await tester.pump(const Duration(milliseconds: 900));
    expect(poseDe(tester)['torso']!.storage, antes);
  });

  testWidgets('desmontar a mitad de animacion no deja excepciones', (
    tester,
  ) async {
    await tester.pumpWidget(host(const TutorialInstructor(height: 150)));
    await asentar(tester);
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
  });
}
