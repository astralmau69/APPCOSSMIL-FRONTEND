import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/models/user_model.dart';
import 'package:cossmil/core/session/user_session.dart';
import 'package:cossmil/features/auth/screens/password_change_screen.dart';

const _user = UserModel(
  id: '4821',
  fullName: 'Juan Perez Mamani',
  rank: 'CORONEL',
  matricula: 'M-12345',
  bloodType: 'O+',
  age: 44,
  gender: 'M',
  role: 'titular',
  isEnabled: true,
  beneficiaries: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    UserSession.currentUser = _user;
  });
  tearDown(UserSession.clear);

  testWidgets('muestra los requisitos de contrasena', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordChangeScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Al menos 6 caracteres'), findsOneWidget);
    expect(find.text('Un carácter especial (- _ @ # ! …)'), findsOneWidget);
  });

  testWidgets('tilda los requisitos al escribir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordChangeScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Militar-2026',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsWidgets);
  });
}
