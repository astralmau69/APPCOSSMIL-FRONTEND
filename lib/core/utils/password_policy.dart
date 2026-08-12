/// Requisitos que debe cumplir una contraseña nueva.
///
/// Fuente única de verdad: la usan tanto el diálogo de cambio en Perfil como
/// la pantalla obligatoria de primer ingreso. Antes cada una validaba distinto
/// (Perfil exigía mayúscula + especial, primer ingreso solo 6 caracteres).
enum PasswordRule { minLength, uppercase, lowercase, digit, special }

/// Nivel informativo de la barra de seguridad. No bloquea el envío: el botón
/// se habilita cuando no queda ninguna [PasswordRule] incumplida, lo que
/// corresponde a [PasswordStrength.buena] o superior.
enum PasswordStrength { muyDebil, debil, buena, fuerte }

class PasswordPolicy {
  PasswordPolicy._();

  /// Mínimo de caracteres. Se mantiene en 6 (no 8) por decisión de producto.
  static const int minLength = 6;

  /// A partir de esta longitud, cumpliendo todas las reglas, la barra marca
  /// "Fuerte".
  static const int strongLength = 12;

  // Las letras acentuadas y la eñe son LETRAS, no caracteres especiales: el
  // teclado en español las pone a un toque y contarlas como especiales dejaría
  // pasar "Contraseña1" como si tuviera un símbolo.
  static const String _upperAccents = 'ÁÉÍÓÚÜÑ';
  static const String _lowerAccents = 'áéíóúüñ';

  static final RegExp _upper = RegExp('[A-Z$_upperAccents]');
  static final RegExp _lower = RegExp('[a-z$_lowerAccents]');
  static final RegExp _digit = RegExp(r'[0-9]');

  /// Cualquier carácter que no sea letra (con o sin acento) ni dígito.
  /// Deliberadamente amplio: el set cerrado anterior omitía `- _ + = / \ ; ' [ ] ~`
  /// y rechazaba contraseñas fuertes como `Militar-2026`.
  static final RegExp _special = RegExp(
    '[^A-Za-z0-9$_upperAccents$_lowerAccents]',
  );

  /// Reglas que [password] todavía NO cumple. Vacío ⇒ es válida.
  static Set<PasswordRule> unmet(String password) {
    return {
      if (password.length < minLength) PasswordRule.minLength,
      if (!_upper.hasMatch(password)) PasswordRule.uppercase,
      if (!_lower.hasMatch(password)) PasswordRule.lowercase,
      if (!_digit.hasMatch(password)) PasswordRule.digit,
      if (!_special.hasMatch(password)) PasswordRule.special,
    };
  }

  static bool isValid(String password) => unmet(password).isEmpty;

  static PasswordStrength strengthOf(String password) {
    final met = PasswordRule.values.length - unmet(password).length;
    if (met < 3) return PasswordStrength.muyDebil;
    if (met < PasswordRule.values.length) return PasswordStrength.debil;
    return password.length >= strongLength
        ? PasswordStrength.fuerte
        : PasswordStrength.buena;
  }

  static String labelFor(PasswordRule rule) => switch (rule) {
    PasswordRule.minLength => 'Al menos $minLength caracteres',
    PasswordRule.uppercase => 'Una letra mayúscula',
    PasswordRule.lowercase => 'Una letra minúscula',
    PasswordRule.digit => 'Un número',
    PasswordRule.special => 'Un carácter especial (- _ @ # ! …)',
  };

  static String labelForStrength(PasswordStrength s) => switch (s) {
    PasswordStrength.muyDebil => 'Muy débil',
    PasswordStrength.debil => 'Débil',
    PasswordStrength.buena => 'Buena',
    PasswordStrength.fuerte => 'Fuerte',
  };
}
