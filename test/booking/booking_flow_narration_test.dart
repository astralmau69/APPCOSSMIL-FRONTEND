import 'package:cossmil/core/tutorial/tutorial_script.dart';
import 'package:cossmil/features/booking/screens/booking_flow_screen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Qué clip suena en cada pantalla del flujo. El TEXTO de cada clip lo cuida
/// `test/core/tutorial_script_test.dart`; aquí solo importa que el paso y la
/// locución no se descoloquen entre sí.
void main() {
  const guiados = [
    'guiado_regional',
    'guiado_especialidad',
    'guiado_medico',
    'guiado_dia',
    'guiado_hora',
    'guiado_confirmar',
  ];

  test('el Modo Guiado narra su propia serie, paso a paso', () {
    for (var step = 0; step < guiados.length; step++) {
      expect(
        bookingVoiceId(guided: true, step: step, confirmed: false),
        guiados[step],
      );
    }
    expect(
      bookingVoiceId(guided: true, step: 5, confirmed: true),
      'guiado_final',
    );
  });

  test('el tutorial-demo sigue con ficha_01..07, sin contagiarse', () {
    for (var step = 0; step < guiados.length; step++) {
      expect(
        bookingVoiceId(guided: false, step: step, confirmed: false),
        'ficha_0${step + 1}',
      );
    }
    expect(bookingVoiceId(guided: false, step: 5, confirmed: true), 'ficha_07');
  });

  test('las burbujas de cada paso son las del clip que suena', () {
    for (final guided in [true, false]) {
      for (final confirmed in [true, false]) {
        for (var step = 0; step < guiados.length; step++) {
          final id = bookingVoiceId(
            guided: guided,
            step: step,
            confirmed: confirmed,
          );
          expect(
            bookingCoachMessages(
              guided: guided,
              step: step,
              confirmed: confirmed,
            ),
            tutorialBubbles(id),
            reason: 'paso $step (guiado: $guided, confirmado: $confirmed)',
          );
        }
      }
    }
  });
}
