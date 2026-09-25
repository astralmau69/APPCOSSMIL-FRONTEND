import 'package:cossmil/features/booking/widgets/booking_mode_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La hoja solo PREGUNTA: devuelve la elección (o null si se descarta) y
/// nunca arranca una reserva por su cuenta — de eso se encarga `startBooking`.
void main() {
  for (final mode in [BookingMode.clasico, BookingMode.guiado, null]) {
    testWidgets('devuelve $mode sin iniciar nada', (tester) async {
      BookingMode? elegido;
      var respondio = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                elegido = await showBookingModeSheet(context);
                respondio = true;
              },
              child: const Text('Reservar'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mode_clasico')), findsOneWidget);
      expect(find.byKey(const Key('mode_guiado')), findsOneWidget);

      await tester.tap(
        mode == null
            ? find.text('Cancelar')
            : find.byKey(Key('mode_${mode.name}')),
      );
      await tester.pumpAndSettle();

      expect(respondio, isTrue);
      expect(elegido, mode);
    });
  }
}
