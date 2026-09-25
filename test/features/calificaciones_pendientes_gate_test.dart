import 'dart:convert';

import 'package:cossmil/core/models/user_model.dart';
import 'package:cossmil/core/services/api_client.dart';
import 'package:cossmil/core/services/programacion_service.dart';
import 'package:cossmil/core/session/user_session.dart';
import 'package:cossmil/features/reservas/widgets/calificaciones_pendientes_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProgramacionService _service(int status, Map<String, dynamic> body) =>
    ProgramacionService(
      apiClient: ApiClient(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(body),
            status,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );

Map<String, dynamic> _pendiente(int idtran) => {
  'codadm': '2026-1-1-$idtran-10',
  'medico': 'VILLAGOMEZ POSTIGO MARIANELA',
  'especialidad': 'MEDICINA GENERAL',
  'fechaCita': '2026-01-13',
  'idmed': '77',
  'idesp': 42,
  'gestion': 2026,
  'idins': 1,
  'idsuc': 1,
  'idtran': idtran,
  'dr': 10,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUp(() {
    // Los tests terminan con la barrera en pantalla (no se puede cerrar), así
    // que su guard de "ya abierta" hay que olvidarlo entre uno y otro.
    CalificacionesPendientesGate.debugReset();
    SharedPreferences.setMockInitialValues({});
    UserSession.currentUser = const UserModel(
      id: '5179',
      fullName: 'Test Usuario',
      rank: 'Soldado',
      matricula: 'M001',
      bloodType: 'O+',
      age: 30,
      role: 'Titular',
      isEnabled: true,
      beneficiaries: [],
    );
  });

  /// Monta una pantalla cualquiera y dispara la barrera sobre ella.
  Future<void> abrir(WidgetTester tester, ProgramacionService service) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => CalificacionesPendientesGate.showIfNeeded(
              context,
              service: service,
            ),
            child: const Text('entrar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('entrar'));
    await tester.pumpAndSettle();
  }

  testWidgets('sin pendientes no se muestra nada', (tester) async {
    await abrir(tester, _service(200, {'ok': true, 'data': []}));
    expect(find.textContaining('calificar'), findsNothing);
    expect(find.text('entrar'), findsOneWidget);
  });

  testWidgets('con pendientes lista las atenciones y no se puede descartar', (
    tester,
  ) async {
    await abrir(
      tester,
      _service(200, {
        'ok': true,
        'data': [_pendiente(165), _pendiente(166)],
      }),
    );

    expect(find.text('Le faltan calificar 2 atenciones'), findsOneWidget);
    expect(find.text('Villagomez Postigo Marianela'), findsNWidgets(2));

    // Tocar fuera del cuadro no la cierra.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Le faltan calificar 2 atenciones'), findsOneWidget);

    // El botón atrás de Android tampoco.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Le faltan calificar 2 atenciones'), findsOneWidget);
  });

  testWidgets('una sola atención se anuncia en singular', (tester) async {
    await abrir(
      tester,
      _service(200, {
        'ok': true,
        'data': [_pendiente(165)],
      }),
    );
    expect(find.text('Le falta calificar una atención'), findsOneWidget);
  });

  testWidgets('si la consulta falla bloquea igual, con reintento', (
    tester,
  ) async {
    await abrir(tester, _service(500, {'ok': false, 'message': 'boom'}));
    // ApiClient reintenta con backoff antes de rendirse; hay que dejar correr
    // ese tiempo para ver el estado de error.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos verificar sus calificaciones'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    // No poder consultar no es lo mismo que no haya nada pendiente: sigue sin
    // dejar pasar.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos verificar sus calificaciones'), findsOneWidget);
  });

  testWidgets('sin idper usable no se bloquea al usuario', (tester) async {
    UserSession.currentUser = const UserModel(
      id: '',
      fullName: 'Sin idper',
      rank: '',
      matricula: '',
      bloodType: '',
      age: 0,
      role: 'Titular',
      isEnabled: true,
      beneficiaries: [],
    );
    await abrir(
      tester,
      _service(200, {
        'ok': true,
        'data': [_pendiente(165)],
      }),
    );
    expect(find.textContaining('calificar'), findsNothing);
  });
}
