import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/animations/app_page_route.dart';
import 'package:cossmil/core/constants/app_sounds.dart';
import 'package:cossmil/core/routing/sound_navigator_observer.dart';
import 'package:cossmil/core/theme/sound_manager.dart';

void main() {
  late List<String> reproducidos;

  setUp(() {
    reproducidos = [];
    SoundManager.debugResetThrottle();
    SoundManager.debugPlayHook = reproducidos.add;
  });

  tearDown(() {
    SoundManager.debugPlayHook = null;
    SoundManager.debugResetThrottle();
  });

  Widget appConObservador(GlobalKey<NavigatorState> navKey) => CupertinoApp(
    navigatorKey: navKey,
    navigatorObservers: [SoundNavigatorObserver()],
    home: const Center(child: Text('inicio')),
  );

  testWidgets('volver de una pantalla suena', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(appConObservador(navKey));

    navKey.currentState!.push(
      CupertinoPageRoute(builder: (_) => const Center(child: Text('detalle'))),
    );
    await tester.pumpAndSettle();
    expect(
      reproducidos,
      isEmpty,
      reason: 'avanzar no dispara el sonido de atrás',
    );

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(reproducidos, [AppSounds.back]);
  });

  testWidgets('cerrar un diálogo NO suena a "atrás"', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(appConObservador(navKey));

    showCupertinoDialog<void>(
      context: navKey.currentContext!,
      builder: (_) => const CupertinoAlertDialog(title: Text('hola')),
    );
    await tester.pumpAndSettle();

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(reproducidos, isEmpty);
  });

  testWidgets('volver de una AppPageRoute también suena', (tester) async {
    // `TabShell.openSubRoute` — la vía centralizada de navegación de la app —
    // usa AppPageRoute. Si dejara de ser una PageRoute, el sonido de atrás
    // desaparecería en silencio de casi toda la app.
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(appConObservador(navKey));

    navKey.currentState!.push(
      AppPageRoute(builder: (_) => const Center(child: Text('detalle'))),
    );
    await tester.pumpAndSettle();

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(reproducidos, [AppSounds.back]);
  });

  testWidgets('cerrar varias pantallas de golpe suena una sola vez', (
    tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(appConObservador(navKey));

    for (var i = 0; i < 3; i++) {
      navKey.currentState!.push(
        CupertinoPageRoute(builder: (_) => Center(child: Text('n$i'))),
      );
      await tester.pumpAndSettle();
    }

    // popUntil emite un didPop por cada pantalla cerrada: el antirrebote los
    // colapsa porque para el usuario fue un único gesto.
    navKey.currentState!.popUntil((r) => r.isFirst);
    await tester.pumpAndSettle();
    expect(reproducidos, [AppSounds.back]);
  });
}
