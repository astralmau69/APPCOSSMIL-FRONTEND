import 'package:cossmil/features/booking/widgets/booking_mode_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [BookingMode.clasico, BookingMode.guiado, null]) {
    testWidgets('selector devuelve $mode sin iniciar una reserva', (tester) async {
      BookingMode? picked;
      var completed = false;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => TextButton(
        onPressed: () async {
          picked = await showBookingModeSheet(context);
          completed = true;
        }, child: const Text('Reservar'),
      ))));
      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mode_clasico')), findsOneWidget);
      expect(find.byKey(const Key('mode_guiado')), findsOneWidget);
      await tester.tap(mode == null ? find.text('Cancelar') : find.byKey(Key('mode_${mode.name}')));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(picked, mode);
    });
  }
}
