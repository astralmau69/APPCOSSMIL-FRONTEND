import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/shell/tab_shell.dart';

/// El Modo Guiado es una reserva REAL narrada. Su bandera vive aparte de
/// `isTutorialMode` justamente porque ésa apaga las llamadas de negocio: si se
/// confundieran, el Modo Guiado no crearía la cita.
void main() {
  test('guidedMode arranca en false y se limpia en el reset', () {
    final bs = BookingState();
    expect(bs.guidedMode, isFalse);

    bs.guidedMode = true;
    bs.reset();
    expect(bs.guidedMode, isFalse);
  });

  test('guidedMode e isTutorialMode son independientes', () {
    final bs = BookingState();
    bs.guidedMode = true;
    expect(
      bs.isTutorialMode,
      isFalse,
      reason: 'el modo guiado NO debe encender el modo demo: crearia una cita falsa',
    );

    bs.isTutorialMode = true;
    bs.guidedMode = false;
    expect(bs.isTutorialMode, isTrue);
  });
}
