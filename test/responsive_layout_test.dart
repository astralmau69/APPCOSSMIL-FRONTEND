import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/theme/sound_manager.dart';
import 'package:cossmil/features/auth/screens/login_screen.dart';

void main() {
  // LoginScreen intenta reproducir la locución de login (audioplayers) tras un
  // delay; en test eso deja un Timer del plugin pendiente que hace fallar el
  // teardown. Desactivar el sonido corta `playIfAllowed` antes de tocar el
  // canal de audio. (Se fija el notifier directo para no escribir en storage.)
  SoundManager.soundEnabledNotifier.value = false;

  testWidgets('LoginScreen no lanza exceptions de layout en pantallas pequeñas', (
    WidgetTester tester,
  ) async {
    // Simulamos una pantalla de teléfono pequeño (e.g. iPhone SE)
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;

    // Al restaurar a default al final
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Si no throwea excepciones de rendering (y termina el pump), pasó.
    // Un overflow de layout lanzaría durante el pump de arriba.
    expect(find.byType(LoginScreen), findsOneWidget);

    // OJO: LoginScreen tiene una animación de flotación en bucle
    // (`_floatCtrl.repeat`), así que pumpAndSettle() NUNCA asienta y se cuelga.
    // Basta con avanzar unos frames (dispara el callback diferido de 200 ms y
    // renderiza) para ejercitar el layout sin esperar a que terminen animaciones.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('LoginScreen se restringe correctamente en tablets anchas', (
    WidgetTester tester,
  ) async {
    // Simulamos una pantalla extra ancha (e.g. iPad Pro en Landscape)
    tester.view.physicalSize = const Size(1366 * 2, 1024 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    // Sin pumpAndSettle (animación en bucle): frames acotados bastan para que
    // el layout quede resuelto antes de medir.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verificamos que el formulario está contenido (buscamos el ConstrainedBox)
    // Buscamos un widget TextField y revisamos si su ancho no excede el max width 450
    final iter = find.byType(TextField).evaluate();
    if (iter.isNotEmpty) {
      final RenderBox box = iter.first.findRenderObject() as RenderBox;
      expect(box.size.width, lessThanOrEqualTo(450));
    }
  });
}
