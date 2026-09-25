import 'dart:convert';
import 'dart:io';

import 'package:cossmil/core/tutorial/tutorial_script.dart';
import 'package:flutter_test/flutter_test.dart';

/// El guion de las burbujas y los mp3 de la instructora tienen que decir lo
/// mismo. Al regenerar las voces con el modelo nuevo cambiaron 23 de las 27
/// líneas y las burbujas se quedaron con el texto viejo: la instructora decía
/// una cosa y mostraba otra. Esto lo detecta antes de que llegue al teléfono.
void main() {
  final lineas =
      (jsonDecode(
                File('tools/rvc/tutorial_lines.json').readAsStringSync(),
              )
              as Map<String, dynamic>)['lines']
          as Map<String, dynamic>;

  test('el guion cubre exactamente los clips grabados', () {
    expect(kTutorialScript.keys.toSet(), lineas.keys.toSet());
  });

  test('cada clip existe como mp3 en assets', () {
    for (final id in kTutorialScript.keys) {
      expect(
        File('assets/vof_tutorial/$id.mp3').existsSync(),
        isTrue,
        reason: 'falta assets/vof_tutorial/$id.mp3',
      );
    }
  });

  group('las burbujas dicen lo que dice la locución', () {
    lineas.forEach((id, texto) {
      test(id, () {
        final burbujas = tutorialBubbles(id);
        expect(burbujas, isNotEmpty);
        expect(burbujas.join(' '), texto);
        // Sin emojis: el clip no los pronuncia y el lector de pantalla los
        // deletrea en medio de la instrucción.
        expect(
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true)
              .hasMatch(burbujas.join()),
          isFalse,
        );
      });
    });
  });

  test('un id sin guion no revienta: devuelve vacío', () {
    expect(tutorialBubbles('no_existe'), isEmpty);
    expect(tutorialBubbles(null), isEmpty);
  });
}
