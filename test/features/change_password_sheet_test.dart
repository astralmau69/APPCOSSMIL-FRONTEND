import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/features/perfil/widgets/change_password_sheet.dart';

Widget _host() => const MaterialApp(home: Scaffold(body: ChangePasswordSheet()));

/// Encuentra el botón principal por su texto.
Finder get _submit => find.widgetWithText(CupertinoButton, 'Cambiar contraseña');

void main() {
  testWidgets('el boton arranca deshabilitado', (tester) async {
    await tester.pumpWidget(_host());
    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNull);
  });

  testWidgets('el boton sigue deshabilitado con una contrasena incompleta', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    // Sin caracter especial.
    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar2026');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Militar2026');
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNull);
  });

  testWidgets('el boton sigue deshabilitado si no coinciden', (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar-2026');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Militar-2027');
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNull);
  });

  testWidgets('el boton se habilita con todo cumplido y coincidente', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar-2026');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Militar-2026');
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('los requisitos se tildan mientras se escribe', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);

    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar-2026');
    await tester.pump(const Duration(milliseconds: 400));
    // 5 reglas de la contrasena; la de coincidencia sigue sin cumplirse.
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(5));
  });

  testWidgets('no desborda en un telefono chico', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
