import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/extensions/responsive_extensions.dart';

/// Monta un widget con el tamaño dado y devuelve el AppResponsive resultante.
Future<AppResponsive> _responsiveAt(WidgetTester tester, Size size) async {
  late AppResponsive captured;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(
        builder: (context) {
          captured = context.r;
          return const SizedBox();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  // En test, kIsWeb es false: se ejercita la rama NATIVA, que es justamente la
  // que estaba rota (tablet horizontal recibía barra lateral).
  group('useSideNav en nativo (kIsWeb == false)', () {
    testWidgets('telefono vertical: barra abajo', (tester) async {
      final r = await _responsiveAt(tester, const Size(375, 812));
      expect(r.useSideNav, isFalse);
    });

    testWidgets('tablet vertical: barra abajo', (tester) async {
      final r = await _responsiveAt(tester, const Size(768, 1024));
      expect(r.useSideNav, isFalse);
    });

    testWidgets('tablet HORIZONTAL: barra abajo (antes era lateral)', (
      tester,
    ) async {
      final r = await _responsiveAt(tester, const Size(1024, 768));
      expect(r.useSideNav, isFalse);
    });

    testWidgets('pantalla ancha nativa: sigue con barra abajo', (tester) async {
      final r = await _responsiveAt(tester, const Size(1440, 900));
      expect(r.useSideNav, isFalse);
    });
  });

  group('navBarBottomSpace acompaña a useSideNav', () {
    testWidgets('reserva espacio siempre que la barra va abajo', (tester) async {
      for (final size in const [
        Size(375, 812),
        Size(768, 1024),
        Size(1024, 768),
        Size(1440, 900),
      ]) {
        final r = await _responsiveAt(tester, size);
        expect(
          r.navBarBottomSpace > 0,
          !r.useSideNav,
          reason:
              'en $size la reserva debe coincidir con la posición de la barra',
        );
      }
    });
  });

  test('el umbral de navegación lateral es 900', () {
    expect(kSideNavMinWidth, 900);
  });
}
