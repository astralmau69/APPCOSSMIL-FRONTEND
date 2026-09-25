import 'dart:convert';
import 'dart:io';

import 'package:cossmil/features/booking/screens/booking_flow_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = (jsonDecode(File('tools/rvc/tutorial_lines.json').readAsStringSync()) as Map<String, dynamic>)['lines'] as Map<String, dynamic>;
  test('cada paso guiado usa la voz y el texto grabados vigentes', () {
    const ids = ['guiado_regional', 'guiado_especialidad', 'guiado_medico', 'guiado_dia', 'guiado_hora', 'guiado_confirmar'];
    for (var step = 0; step < ids.length; step++) {
      expect(bookingVoiceId(guided: true, step: step, confirmed: false), ids[step]);
      expect(bookingCoachMessages(guided: true, step: step, confirmed: false).join(' '), script[ids[step]]);
      expect(bookingVoiceId(guided: false, step: step, confirmed: false), 'ficha_0${step + 1}');
    }
    expect(bookingVoiceId(guided: true, step: 5, confirmed: true), 'guiado_final');
    expect(bookingCoachMessages(guided: true, step: 5, confirmed: true).join(' '), script['guiado_final']);
    expect(bookingGuidedIntroMessages.join(' '), script['guiado_intro']);
    expect(bookingVoiceId(guided: false, step: 5, confirmed: true), 'ficha_07');
    expect(bookingCoachMessages(guided: false, step: 5, confirmed: true).join(' '), contains('no se creó ninguna cita real'));
  });
}
