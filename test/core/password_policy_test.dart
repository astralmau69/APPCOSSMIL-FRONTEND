import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/utils/password_policy.dart';

/// QA del validador de contraseña compartido por el diálogo de Perfil y la
/// pantalla de primer ingreso.
void main() {
  group('PasswordPolicy · regresión del bug reportado', () {
    test('acepta Militar-2026 (el guion era rechazado por el set viejo)', () {
      expect(PasswordPolicy.unmet('Militar-2026'), isEmpty);
      expect(PasswordPolicy.isValid('Militar-2026'), isTrue);
    });

    test('acepta guion bajo, mas y igual como caracteres especiales', () {
      for (final pwd in ['Cossmil_2026', 'Cossmil+2026', 'Cossmil=2026']) {
        expect(PasswordPolicy.isValid(pwd), isTrue, reason: pwd);
      }
    });
  });

  group('PasswordPolicy · reglas incumplidas', () {
    test('una cadena vacia incumple todas las reglas', () {
      expect(PasswordPolicy.unmet(''), PasswordRule.values.toSet());
    });

    test('senala exactamente la regla que falta', () {
      // Todo menos mayuscula.
      expect(PasswordPolicy.unmet('militar-2026'), {PasswordRule.uppercase});
      // Todo menos minuscula.
      expect(PasswordPolicy.unmet('MILITAR-2026'), {PasswordRule.lowercase});
      // Todo menos digito.
      expect(PasswordPolicy.unmet('Militar-abcd'), {PasswordRule.digit});
      // Todo menos especial.
      expect(PasswordPolicy.unmet('Militar2026'), {PasswordRule.special});
      // Todo menos longitud (5 caracteres).
      expect(PasswordPolicy.unmet('Ab1!c'), {PasswordRule.minLength});
    });

    test('acepta exactamente en el minimo de 6 caracteres', () {
      expect(PasswordPolicy.unmet('Abc12!'), isEmpty);
    });
  });

  group('PasswordPolicy · acentos y enie', () {
    // El teclado en espanol los pone a un toque; la enie es una LETRA, no un
    // caracter especial. Con un set de especiales ingenuo ([^A-Za-z0-9]) la
    // enie contaria como especial y 'Contrasena1' pasaria sin serlo.
    test('la enie cuenta como minuscula, no como especial', () {
      expect(PasswordPolicy.unmet('Contraseña1'), {PasswordRule.special});
    });

    test('las vocales acentuadas cuentan como letras', () {
      // 'special' sigue incumplida en ambos casos JUSTAMENTE porque la vocal
      // acentuada es una letra: si contara como especial, estas cadenas
      // pasarian por tener simbolo sin tener ninguno.
      expect(PasswordPolicy.unmet('MILITARÍA1'), {
        PasswordRule.lowercase,
        PasswordRule.special,
      });
      expect(PasswordPolicy.unmet('militaría1'), {
        PasswordRule.uppercase,
        PasswordRule.special,
      });
      // Con un simbolo de verdad, la unica regla que falta es la de caso.
      expect(PasswordPolicy.unmet('MILITARÍA-1'), {PasswordRule.lowercase});
      expect(PasswordPolicy.unmet('militaría-1'), {PasswordRule.uppercase});
    });
  });

  group('PasswordPolicy · barra de seguridad', () {
    test('menos de 3 reglas cumplidas es muy debil', () {
      // Solo minuscula.
      expect(PasswordPolicy.strengthOf('abc'), PasswordStrength.muyDebil);
    });

    test('3 o 4 reglas cumplidas es debil', () {
      // longitud + minuscula + mayuscula = 3.
      expect(PasswordPolicy.strengthOf('Abcdef'), PasswordStrength.debil);
      // longitud + minuscula + mayuscula + digito = 4.
      expect(PasswordPolicy.strengthOf('Abcde1'), PasswordStrength.debil);
    });

    test('todas las reglas con menos de 12 caracteres es buena', () {
      expect(PasswordPolicy.strengthOf('Abc12!'), PasswordStrength.buena);
    });

    test('todas las reglas con 12 o mas caracteres es fuerte', () {
      expect(PasswordPolicy.strengthOf('Militar-2026'), PasswordStrength.fuerte);
    });
  });

  group('PasswordPolicy · sin trim', () {
    // perfil_screen.dart hacia .trim(), alterando en silencio lo que se guarda
    // respecto de lo que el usuario tecleo.
    test('el espacio final cuenta y no se descarta', () {
      expect(PasswordPolicy.unmet('Abc123 '), isEmpty);
      expect('Abc123 '.length, 7);
    });
  });

  group('PasswordPolicy · etiquetas', () {
    test('cada regla tiene una etiqueta no vacia', () {
      for (final rule in PasswordRule.values) {
        expect(PasswordPolicy.labelFor(rule), isNotEmpty);
      }
    });

    test('cada nivel de seguridad tiene una etiqueta no vacia', () {
      for (final s in PasswordStrength.values) {
        expect(PasswordPolicy.labelForStrength(s), isNotEmpty);
      }
    });
  });
}
