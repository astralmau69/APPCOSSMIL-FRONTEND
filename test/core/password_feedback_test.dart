import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/utils/password_policy.dart';
import 'package:cossmil/core/widgets/password_feedback.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 375, child: child)),
);

void main() {
  group('PasswordChecklist', () {
    testWidgets('muestra una fila por regla', (tester) async {
      await tester.pumpWidget(_host(const PasswordChecklist(password: '')));
      for (final rule in PasswordRule.values) {
        expect(find.text(PasswordPolicy.labelFor(rule)), findsOneWidget);
      }
    });

    testWidgets('sin nada escrito no hay ningun tilde', (tester) async {
      await tester.pumpWidget(_host(const PasswordChecklist(password: '')));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);
    });

    testWidgets('con una contrasena valida tilda las 5 reglas', (tester) async {
      await tester.pumpWidget(
        _host(const PasswordChecklist(password: 'Militar-2026')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(5));
    });

    testWidgets('tilda solo las reglas cumplidas', (tester) async {
      // 'Militar2026' cumple todo menos el caracter especial.
      await tester.pumpWidget(
        _host(const PasswordChecklist(password: 'Militar2026')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(4));
    });

    testWidgets('con confirm agrega la fila de coincidencia', (tester) async {
      await tester.pumpWidget(
        _host(
          const PasswordChecklist(
            password: 'Militar-2026',
            confirm: 'Militar-2026',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Las contraseñas coinciden'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(6));
    });

    testWidgets('confirm distinto no tilda la coincidencia', (tester) async {
      await tester.pumpWidget(
        _host(const PasswordChecklist(password: 'Militar-2026', confirm: 'otra')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(5));
    });
  });

  group('PasswordStrengthBar', () {
    testWidgets('muestra la etiqueta del nivel actual', (tester) async {
      await tester.pumpWidget(
        _host(const PasswordStrengthBar(password: 'Militar-2026')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Fuerte'), findsOneWidget);
    });

    testWidgets('cambia de etiqueta al cambiar la contrasena', (tester) async {
      await tester.pumpWidget(_host(const PasswordStrengthBar(password: 'abc')));
      expect(find.text('Muy débil'), findsOneWidget);

      await tester.pumpWidget(
        _host(const PasswordStrengthBar(password: 'Abc12!')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buena'), findsOneWidget);
    });

    testWidgets('no desborda en un telefono chico', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(const PasswordFeedback(password: 'Militar-2026', confirm: '')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
