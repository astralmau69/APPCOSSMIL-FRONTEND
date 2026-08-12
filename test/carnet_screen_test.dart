import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/models/user_model.dart';
import 'package:cossmil/core/session/user_session.dart';
import 'package:cossmil/features/carnet/screens/carnet_screen.dart';
import 'package:cossmil/features/carnet/widgets/carnet_card.dart';

/// Usuario de prueba con los campos que el carnet dibuja.
const _user = UserModel(
  id: '4821',
  fullName: 'Juan Perez Mamani',
  rank: 'CORONEL',
  matricula: 'M-12345',
  bloodType: 'O+',
  age: 44,
  role: 'titular',
  ci: '1234567',
  fuerza: 'EJERCITO',
  birthDate: '1981-05-14',
  numCel: '71292794',
  beneficiaries: [],
);

/// Monta [CarnetScreen] con o sin reduce-motion.
Widget _app({bool reduceMotion = false, Size size = const Size(430, 932)}) {
  return MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: reduceMotion),
    child: const MaterialApp(home: CarnetScreen()),
  );
}

void main() {
  // El carnet arrastra ScreenSecurityService y TokenStorage por debajo: sin
  // binding + mock de secure-storage el árbol ni llega a montarse.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    UserSession.currentUser = _user;
  });

  tearDown(UserSession.clear);

  testWidgets('muestra el frente del carnet con los datos del usuario', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    // Supera la secuencia de entrada completa (AppDurations.extra = 1000 ms).
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Mi Carnet COSSMIL'), findsOneWidget);
    expect(find.text('Toca para ver el reverso'), findsOneWidget);
    // Un solo frente: las tarjetas de captura para el PDF ya NO se montan en
    // reposo (antes se pintaban dos carnets completos fuera de pantalla cada
    // vez que se entraba). El reverso no existe hasta que se gira.
    expect(find.byType(CarnetCardFront), findsOneWidget);
    expect(find.byType(CarnetCardBack), findsNothing);
  });

  testWidgets('al tocar la tarjeta gira y la ayuda pasa al reverso', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.byKey(carnetFlipKey));
    // El primer pump solo pone el ticker en marcha (su reloj arranca en este
    // frame, sin consumir tiempo); recién el siguiente avanza el giro.
    await tester.pump();
    // Giro completo (AppDurations.verySlow = 700 ms) más el cruce de la ayuda
    // (AnimatedSwitcher, AppDurations.quick = 200 ms).
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Reverso · toca para volver al frente'), findsOneWidget);
    expect(find.text('Toca para ver el reverso'), findsNothing);
  });

  testWidgets('con reduce-motion el giro es instantáneo y no queda animación', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    await tester.pump();

    // Sin secuencia de entrada: el contenido está desde el primer frame.
    expect(find.text('Toca para ver el reverso'), findsOneWidget);

    await tester.tap(find.byKey(carnetFlipKey));
    await tester.pump();

    expect(find.text('Reverso · toca para volver al frente'), findsOneWidget);
    // Sin reduce-motion el holograma dejaría frames agendados; aquí no debe
    // quedar ninguno, por eso pumpAndSettle no se cuelga.
    await tester.pumpAndSettle();
  });

  testWidgets('el holograma deja de agendar frames cuando el carnet reposa', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    // El ticker del holograma se detiene solo tras ~30 frames sin movimiento;
    // si siguiera corriendo en bucle, pumpAndSettle nunca volvería.
    await tester.pumpAndSettle(const Duration(milliseconds: 16));
  });

  testWidgets('las acciones del carnet están rotuladas por lo que hacen', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Descargar PDF'), findsOneWidget);
    expect(find.text('Compartir'), findsOneWidget);
    expect(find.text('Carnet Digital de Seguro'), findsOneWidget);
    expect(find.text('Validar un carnet'), findsOneWidget);
  });

  group('reparto por ancho disponible', () {
    // El ancho de la ventana es lo único que decide el reparto, así que un
    // teléfono en el navegador cae en el mismo camino que la app nativa.
    testWidgets('en ancho de teléfono las acciones van DEBAJO de la tarjeta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(size: const Size(430, 932)));
      await tester.pump(const Duration(milliseconds: 1200));

      final tarjeta = tester.getRect(find.byKey(carnetFlipKey));
      final boton = tester.getRect(find.text('Descargar PDF'));
      expect(boton.top, greaterThan(tarjeta.bottom));
    });

    testWidgets('en pantalla ancha las acciones van AL LADO de la tarjeta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(size: const Size(1400, 900)));
      await tester.pump(const Duration(milliseconds: 1200));

      final tarjeta = tester.getRect(find.byKey(carnetFlipKey));
      final boton = tester.getRect(find.text('Descargar PDF'));
      expect(boton.left, greaterThan(tarjeta.right));
      // Y a la vista, no empujado fuera del pliegue.
      expect(boton.top, lessThan(tarjeta.bottom));
    });
  });
}
