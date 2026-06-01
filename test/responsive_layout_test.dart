import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com.cossmil.citamedicapp/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen no lanza exceptions de layout en pantallas pequeñas', (WidgetTester tester) async {
    // Simulamos una pantalla de teléfono pequeño (e.g. iPhone SE)
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    
    // Al restaurar a default al final
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    // Si no throwea excepciones de rendering (y termina el pump), pasó
    expect(find.byType(LoginScreen), findsOneWidget);
    
    // Forzamos frames de animación
    await tester.pumpAndSettle();
  });

  testWidgets('LoginScreen se restringe correctamente en tablets anchas', (WidgetTester tester) async {
    // Simulamos una pantalla extra ancha (e.g. iPad Pro en Landscape)
    tester.view.physicalSize = const Size(1366 * 2, 1024 * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verificamos que el formulario está contenido (buscamos el ConstrainedBox)
    // Buscamos un widget TextField y revisamos si su ancho no excede el max width 450
    final iter = find.byType(TextField).evaluate();
    if (iter.isNotEmpty) {
       final RenderBox box = iter.first.findRenderObject() as RenderBox;
       expect(box.size.width, lessThanOrEqualTo(450));
    }
  });
}
