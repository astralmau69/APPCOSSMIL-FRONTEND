# Responsividad global verificable + política de contraseña — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unificar la validación de contraseña en un solo validador con
retroalimentación en vivo, corregir la regla de navegación duplicada, y montar
un arnés de auditoría de layout que convierta "mejorar la responsividad" en algo
medible.

**Architecture:** Cuatro bloques con dependencias mínimas entre sí. `PasswordPolicy`
es lógica pura sin Flutter (TDD estricto), consumida por dos pantallas. `useSideNav`
se añade a `AppResponsive` y pasa a ser la única fuente de la regla que hoy está
escrita dos veces. El arnés de auditoría se construye **antes** de los arreglos de
layout, para que su primera corrida produzca la lista de defectos reales.

**Tech Stack:** Flutter (Dart SDK ^3.8.1), `flutter_test`, Cupertino widgets,
sistema responsive propio (`core/extensions/responsive_extensions.dart`), tokens
de `core/theme/app_constants.dart`.

**Spec:** `docs/superpowers/specs/2026-08-12-responsividad-global-y-politica-de-contrasena-design.md`

## Global Constraints

- **Idioma:** todo el texto de UI, los nombres de tests y los comentarios van en
  español. Los mensajes de commit también.
- **No se cambia el diseño visual.** El objetivo de las Partes B/C es que nada
  desborde ni se recorte. Si una pantalla se ve bien hoy en 375×812, debe verse
  idéntica después.
- **Nada de `pumpAndSettle`** en tests que monten pantallas con animaciones en
  bucle (login, instructora del tutorial, carnet): nunca asienta y el test se
  cuelga. Usar `pump()` acotados.
- **Tokens, no literales:** usar `context.r` (espaciado, radios, tamaños),
  `context.texts` (tipografía), `AppDurations`/`AppCurves` (movimiento),
  `AppColors` (color). Nunca hardcodear.
- **Reduce-motion:** toda animación nueva respeta
  `MediaQuery.of(context).disableAnimations`.
- **`flutter analyze` limpio** antes de cada commit.
- **Suite completa verde** antes de cada commit: `flutter test`.
- Umbral de navegación lateral: **900 px**, declarado como constante nombrada
  `kSideNavMinWidth`, nunca como literal suelto.
- Longitud mínima de contraseña: **6** (decisión explícita del usuario, no 8).

---

### Task 1: `PasswordPolicy` — validador puro compartido

Lógica pura sin dependencias de Flutter, así que se hace con TDD estricto. Es la
base de la Task 2 y elimina los dos validadores divergentes de
`perfil_screen.dart:1992` y `password_change_screen.dart:74`.

**Files:**
- Create: `lib/core/utils/password_policy.dart`
- Test: `test/core/password_policy_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `enum PasswordRule { minLength, uppercase, lowercase, digit, special }`
  - `enum PasswordStrength { muyDebil, debil, buena, fuerte }`
  - `PasswordPolicy.minLength` → `int` (6)
  - `PasswordPolicy.strongLength` → `int` (12)
  - `PasswordPolicy.unmet(String password)` → `Set<PasswordRule>`
  - `PasswordPolicy.isValid(String password)` → `bool`
  - `PasswordPolicy.strengthOf(String password)` → `PasswordStrength`
  - `PasswordPolicy.labelFor(PasswordRule rule)` → `String`
  - `PasswordPolicy.labelForStrength(PasswordStrength s)` → `String`

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/password_policy_test.dart`:

```dart
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
      expect(PasswordPolicy.unmet('MILITARÍA1'), {PasswordRule.lowercase});
      expect(PasswordPolicy.unmet('militaría1'), {PasswordRule.uppercase});
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
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/core/password_policy_test.dart`
Expected: FAIL — el archivo `password_policy.dart` no existe ("Target of URI doesn't exist").

- [ ] **Step 3: Escribir la implementación mínima**

Crear `lib/core/utils/password_policy.dart`:

```dart
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
```

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/core/password_policy_test.dart`
Expected: PASS — todos los grupos verdes.

Si `la enie cuenta como minuscula` falla, revisar que `_special` excluya
`$_lowerAccents`: es el error fácil de cometer aquí.

- [ ] **Step 5: Verificar y commitear**

```bash
flutter analyze
flutter test
git add lib/core/utils/password_policy.dart test/core/password_policy_test.dart
git commit -m "feat: validador de contraseña compartido con set de especiales amplio

El set anterior ([!@#\$%^&*(),.?\":{}|<>]) omitía - _ + = / \\ ; ' [ ] ~,
así que Militar-2026 se rechazaba como débil. Ahora especial es cualquier
carácter no alfanumérico, con acentos y eñe tratados como letras.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: Widgets de retroalimentación en vivo

La lista de requisitos tildables y la barra de seguridad, como widgets
reutilizables. Se separan del sheet (Task 3) porque los consumen dos pantallas
distintas y porque así se pueden testear sin montar un diálogo.

**Files:**
- Create: `lib/core/widgets/password_feedback.dart`
- Test: `test/core/password_feedback_test.dart`

**Interfaces:**
- Consumes: `PasswordPolicy`, `PasswordRule`, `PasswordStrength` (Task 1).
- Produces:
  - `PasswordStrengthBar({required String password})` — barra + etiqueta.
  - `PasswordChecklist({required String password, String? confirm})` — una fila
    por regla; si `confirm` no es `null`, añade la fila "Las contraseñas coinciden".
  - `PasswordFeedback({required String password, String? confirm})` — compone
    ambas con el espaciado del sistema.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/password_feedback_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/utils/password_policy.dart';
import 'package:cossmil/core/widgets/password_feedback.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 375, child: child)),
);

void main() {
  group('PasswordChecklist', () {
    testWidgets('muestra una fila por regla', (tester) async {
      await tester.pumpWidget(_host(const PasswordChecklist(password: '')));
      for (final rule in PasswordRule.values) {
        expect(find.text(PasswordPolicy.labelFor(rule)), findsOneWidget);
      }
    });

    testWidgets('sin nada escrito no hay ningun tilde', (tester) async {
      await tester.pumpWidget(_host(const PasswordChecklist(password: '')));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);
    });

    testWidgets('con una contrasena valida tilda las 5 reglas', (tester) async {
      await tester.pumpWidget(
        _host(const PasswordChecklist(password: 'Militar-2026')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(5));
    });

    testWidgets('tilda solo las reglas cumplidas', (tester) async {
      // 'Militar2026' cumple todo menos el caracter especial.
      await tester.pumpWidget(
        _host(const PasswordChecklist(password: 'Militar2026')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(4));
    });

    testWidgets('con confirm agrega la fila de coincidencia', (tester) async {
      await tester.pumpWidget(
        _host(
          const PasswordChecklist(password: 'Militar-2026', confirm: 'Militar-2026'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Las contraseñas coinciden'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(6));
    });

    testWidgets('confirm distinto no tilda la coincidencia', (tester) async {
      await tester.pumpWidget(
        _host(const PasswordChecklist(password: 'Militar-2026', confirm: 'otra')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(5));
    });
  });

  group('PasswordStrengthBar', () {
    testWidgets('muestra la etiqueta del nivel actual', (tester) async {
      await tester.pumpWidget(
        _host(const PasswordStrengthBar(password: 'Militar-2026')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Fuerte'), findsOneWidget);
    });

    testWidgets('cambia de etiqueta al cambiar la contrasena', (tester) async {
      await tester.pumpWidget(_host(const PasswordStrengthBar(password: 'abc')));
      expect(find.text('Muy débil'), findsOneWidget);

      await tester.pumpWidget(_host(const PasswordStrengthBar(password: 'Abc12!')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buena'), findsOneWidget);
    });

    testWidgets('no desborda en un telefono chico', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(const PasswordFeedback(password: 'Militar-2026', confirm: '')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/core/password_feedback_test.dart`
Expected: FAIL — `password_feedback.dart` no existe.

- [ ] **Step 3: Escribir la implementación**

Crear `lib/core/widgets/password_feedback.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/app_constants.dart';
import '../utils/password_policy.dart';

/// Barra de seguridad de 4 niveles. Informativa: no bloquea el envío.
class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  static Color colorFor(PasswordStrength s) => switch (s) {
    PasswordStrength.muyDebil => AppColors.error,
    PasswordStrength.debil => const Color(0xFFEA580C),
    PasswordStrength.buena => AppColors.warning,
    PasswordStrength.fuerte => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final strength = PasswordPolicy.strengthOf(password);
    final color = colorFor(strength);
    // Vacío = 0; si no, una cuarta parte por nivel.
    final fraction = password.isEmpty ? 0.0 : (strength.index + 1) / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Seguridad',
              style: context.texts.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            // AnimatedSwitcher para que la etiqueta no "salte" al cambiar.
            AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              child: Text(
                password.isEmpty
                    ? ''
                    : PasswordPolicy.labelForStrength(strength),
                key: ValueKey(password.isEmpty ? '' : strength),
                style: context.texts.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(r.radiusSm),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: AppColors.cardBorder(isDark),
              ),
              // FractionallySizedBox se adapta al ancho disponible: la barra
              // nunca fuerza un ancho propio, así funciona igual en 320 px que
              // en un sheet de tablet.
              AnimatedFractionallySizedBox(
                duration: reduceMotion ? Duration.zero : AppDurations.quick,
                curve: AppCurves.snappy,
                widthFactor: fraction,
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lista de requisitos que se van tildando en vivo mientras el usuario escribe.
class PasswordChecklist extends StatelessWidget {
  final String password;

  /// Si no es null, se añade la fila "Las contraseñas coinciden".
  final String? confirm;

  const PasswordChecklist({super.key, required this.password, this.confirm});

  @override
  Widget build(BuildContext context) {
    final unmet = PasswordPolicy.unmet(password);

    final rows = <Widget>[
      for (final rule in PasswordRule.values)
        _RequirementRow(
          label: PasswordPolicy.labelFor(rule),
          met: !unmet.contains(rule),
        ),
      if (confirm != null)
        _RequirementRow(
          label: 'Las contraseñas coinciden',
          met: password.isNotEmpty && password == confirm,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final color = met ? AppColors.success : AppColors.textTertiaryC(isDark);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spaceXs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.iconSm,
            height: r.iconSm,
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              switchInCurve: AppCurves.snappy,
              child: met
                  ? Icon(
                      CupertinoIcons.checkmark_alt,
                      key: const ValueKey('met'),
                      size: r.iconSm,
                      color: AppColors.success,
                    )
                  : Icon(
                      CupertinoIcons.circle,
                      key: const ValueKey('unmet'),
                      size: r.iconSm * 0.7,
                      color: AppColors.textTertiaryC(isDark),
                    ),
            ),
          ),
          SizedBox(width: r.spaceSm),
          // Expanded: las etiquetas largas envuelven en vez de desbordar en
          // pantallas de 320 px.
          Expanded(
            child: Text(
              label,
              style: context.texts.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de seguridad + lista de requisitos, con el espaciado del sistema.
class PasswordFeedback extends StatelessWidget {
  final String password;
  final String? confirm;

  const PasswordFeedback({super.key, required this.password, this.confirm});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PasswordStrengthBar(password: password),
        SizedBox(height: r.spaceMd),
        PasswordChecklist(password: password, confirm: confirm),
      ],
    );
  }
}
```

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/core/password_feedback_test.dart`
Expected: PASS.

Si `AnimatedFractionallySizedBox` no existe en la versión de Flutter del
proyecto, reemplazar por `AnimatedContainer` dentro de un `LayoutBuilder` que
calcule `constraints.maxWidth * fraction`. Verificar antes con
`grep -rn "AnimatedFractionallySizedBox" $(flutter --version --machine | grep -o '"flutterRoot":"[^"]*"' | cut -d'"' -f4)/packages/flutter/lib/src/widgets/implicit_animations.dart`.

- [ ] **Step 5: Verificar y commitear**

```bash
flutter analyze
flutter test
git add lib/core/widgets/password_feedback.dart test/core/password_feedback_test.dart
git commit -m "feat: lista de requisitos tildable y barra de seguridad de contraseña

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: Sheet de cambio de contraseña en Perfil

Reemplaza el `CupertinoAlertDialog` de `perfil_screen.dart:1930-2061`, que es
demasiado angosto para alojar la lista y la barra. Al extraerlo a su propio
archivo, `perfil_screen.dart` (2062 líneas) pierde 130.

**Files:**
- Create: `lib/features/perfil/widgets/change_password_sheet.dart`
- Modify: `lib/features/perfil/screens/perfil_screen.dart:1930-2061` (borrar
  `_showChangePasswordDialog` completo y delegar)
- Test: `test/features/change_password_sheet_test.dart`

**Interfaces:**
- Consumes: `PasswordPolicy` (Task 1); `PasswordFeedback` (Task 2);
  `AuthService().changePassword({required int idper, required String newPassword})`
  (`auth_service.dart:642`); `ErrorMapper.message(e, context: ErrorContext.cambiarPassword)`
  (`error_mapper.dart:16`); `showAppDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible, bool silent})`
  (`app_dialog.dart:27`).
- Produces: `Future<bool?> showChangePasswordSheet(BuildContext context)` —
  `true` si la contraseña se cambió, `null`/`false` si se canceló.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/features/change_password_sheet_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/features/perfil/widgets/change_password_sheet.dart';

Widget _host() => const MaterialApp(home: Scaffold(body: ChangePasswordSheet()));

/// Encuentra el botón principal por su texto.
Finder get _submit => find.widgetWithText(CupertinoButton, 'Cambiar contraseña');

void main() {
  testWidgets('el boton arranca deshabilitado', (tester) async {
    await tester.pumpWidget(_host());
    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNull);
  });

  testWidgets('el boton sigue deshabilitado con una contrasena incompleta', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    // Sin caracter especial.
    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar2026');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Militar2026');
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNull);
  });

  testWidgets('el boton sigue deshabilitado si no coinciden', (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar-2026');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Militar-2027');
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNull);
  });

  testWidgets('el boton se habilita con todo cumplido y coincidente', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar-2026');
    await tester.enterText(find.byType(CupertinoTextField).last, 'Militar-2026');
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<CupertinoButton>(_submit);
    expect(button.onPressed, isNotNull);
  });

  testWidgets('los requisitos se tildan mientras se escribe', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNothing);

    await tester.enterText(find.byType(CupertinoTextField).first, 'Militar-2026');
    await tester.pump(const Duration(milliseconds: 400));
    // 5 reglas de la contrasena; la de coincidencia sigue sin cumplirse.
    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsNWidgets(5));
  });

  testWidgets('no desborda en un telefono chico', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/features/change_password_sheet_test.dart`
Expected: FAIL — `change_password_sheet.dart` no existe.

- [ ] **Step 3: Escribir el sheet**

Crear `lib/features/perfil/widgets/change_password_sheet.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/animations/app_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/password_feedback.dart';

/// Abre el sheet de cambio de contraseña. Devuelve `true` si se cambió.
Future<bool?> showChangePasswordSheet(BuildContext context) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const ChangePasswordSheet(),
  );
}

/// Formulario de cambio de contraseña con retroalimentación en vivo.
///
/// Sustituye al CupertinoAlertDialog anterior, cuyo ancho fijo no admitía la
/// lista de requisitos ni la barra de seguridad, y que solo informaba del
/// rechazo DESPUÉS de pulsar Guardar.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Redibuja la lista y la barra en cada pulsación.
    _pwdCtrl.addListener(_onChanged);
    _confirmCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // NO se usa .trim(): recortar altera en silencio la contraseña que se guarda
  // respecto de la que el usuario tecleó.
  bool get _canSubmit =>
      !_isSaving &&
      PasswordPolicy.isValid(_pwdCtrl.text) &&
      _pwdCtrl.text == _confirmCtrl.text;

  Future<void> _onSubmit() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      await AuthService().changePassword(
        idper: idper,
        newPassword: _pwdCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        // El backend puede rechazar ciertos caracteres especiales: su mensaje
        // real importa más que un genérico.
        _errorMessage = ErrorMapper.message(
          e,
          context: ErrorContext.cambiarPassword,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.modalMaxWidth),
        child: Material(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(r.modalRadius),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            // El teclado no debe tapar el botón ni la lista.
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(r.modalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cambiar contraseña',
                    style: context.texts.titleLarge.copyWith(
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  SizedBox(height: r.spaceLg),
                  _field(
                    controller: _pwdCtrl,
                    placeholder: 'Nueva contraseña',
                    obscure: _obscurePwd,
                    onToggle: () =>
                        setState(() => _obscurePwd = !_obscurePwd),
                    isDark: isDark,
                    autofocus: true,
                  ),
                  SizedBox(height: r.spaceSm),
                  _field(
                    controller: _confirmCtrl,
                    placeholder: 'Confirmar contraseña',
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    isDark: isDark,
                  ),
                  SizedBox(height: r.spaceLg),
                  PasswordFeedback(
                    password: _pwdCtrl.text,
                    confirm: _confirmCtrl.text,
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: r.spaceMd),
                    Text(
                      _errorMessage!,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  SizedBox(height: r.spaceLg),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancelar',
                            style: context.texts.titleMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: r.spaceSm),
                      Expanded(
                        child: SizedBox(
                          height: r.buttonHeight,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(r.buttonRadius),
                            // Deshabilitado hasta cumplir todo: el rechazo deja
                            // de ser una sorpresa post-envío.
                            onPressed: _canSubmit ? _onSubmit : null,
                            child: _isSaving
                                ? const CupertinoActivityIndicator(
                                    color: AppColors.white,
                                  )
                                : Text(
                                    'Cambiar contraseña',
                                    textAlign: TextAlign.center,
                                    style: context.texts.titleMedium.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
    bool autofocus = false,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscure,
      autofocus: autofocus,
      enabled: !_isSaving,
      padding: EdgeInsets.symmetric(
        horizontal: context.r.tileHorizontalPad,
        vertical: context.r.spaceMd,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(context.r.inputRadius),
        border: Border.all(color: AppColors.cardBorder(isDark)),
      ),
      style: context.texts.bodyLarge.copyWith(
        color: AppColors.textPrimaryC(isDark),
      ),
      suffix: CupertinoButton(
        padding: EdgeInsets.only(right: context.r.spaceSm),
        minimumSize: Size.zero,
        onPressed: onToggle,
        child: Icon(
          obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
          size: context.r.iconSm,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/features/change_password_sheet_test.dart`
Expected: PASS.

Si `AppColors.darkBg` no existe, comprobar el nombre real con
`grep -n "static const Color dark" lib/core/constants/app_colors.dart` y usar
el que corresponda al fondo de un campo en modo oscuro.

- [ ] **Step 5: Conectar Perfil al sheet nuevo**

En `lib/features/perfil/screens/perfil_screen.dart`, borrar el método
`_showChangePasswordDialog` completo (líneas 1930-2061) y sustituirlo por:

```dart
  Future<void> _showChangePasswordDialog() async {
    final changed = await showChangePasswordSheet(context);
    if (changed != true || !mounted) return;
    await CossmilIosAlert.show(
      context: context,
      title: 'Contraseña actualizada',
      message: 'Tu contraseña fue cambiada exitosamente.',
      type: AlertType.success,
      confirmText: 'Aceptar',
    );
  }
```

Añadir el import `import '../widgets/change_password_sheet.dart';` y quitar los
imports que queden sin uso (`flutter analyze` los señala).

- [ ] **Step 6: Verificar y commitear**

```bash
flutter analyze
flutter test
git add lib/features/perfil/ test/features/change_password_sheet_test.dart
git commit -m "fix: el cambio de contraseña muestra en vivo qué falta

El diálogo anterior validaba en silencio al pulsar Guardar y rechazaba
contraseñas fuertes sin decir cuál regla fallaba. Ahora los requisitos se
tildan mientras se escribe, hay barra de seguridad, y el botón se habilita
solo cuando todo se cumple. Se quita el .trim() que alteraba la contraseña
guardada, y el error del backend deja de estar enterrado.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: Unificar el validador en la pantalla de primer ingreso

`password_change_screen.dart:74` solo exige 6 caracteres. Tras la Task 3, un
usuario puede fijar una contraseña débil en el primer ingreso que luego el
diálogo de Perfil rechazaría. Se cierra esa divergencia.

**Files:**
- Modify: `lib/features/auth/screens/password_change_screen.dart:58-131` (validación) y `:219-269` (campos)
- Test: `test/features/password_change_screen_test.dart`

**Interfaces:**
- Consumes: `PasswordPolicy` (Task 1), `PasswordFeedback` (Task 2).
- Produces: nada nuevo.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/features/password_change_screen_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cossmil/core/models/user_model.dart';
import 'package:cossmil/core/session/user_session.dart';
import 'package:cossmil/features/auth/screens/password_change_screen.dart';

const _user = UserModel(
  id: '4821',
  fullName: 'Juan Perez Mamani',
  rank: 'CORONEL',
  matricula: 'M-12345',
  bloodType: 'O+',
  age: 44,
  gender: 'M',
  role: 'titular',
  isEnabled: true,
  beneficiaries: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    UserSession.currentUser = _user;
  });
  tearDown(UserSession.clear);

  testWidgets('muestra los requisitos de contrasena', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordChangeScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Al menos 6 caracteres'), findsOneWidget);
    expect(find.text('Un carácter especial (- _ @ # ! …)'), findsOneWidget);
  });

  testWidgets('tilda los requisitos al escribir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordChangeScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.enterText(
      find.byType(CupertinoTextField).first,
      'Militar-2026',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byIcon(CupertinoIcons.checkmark_alt), findsWidgets);
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/features/password_change_screen_test.dart`
Expected: FAIL — "Al menos 6 caracteres" no aparece; la pantalla no muestra
requisitos.

- [ ] **Step 3: Sustituir la validación e insertar el feedback**

En `password_change_screen.dart`, reemplazar el bloque de validación de longitud
(líneas 74-79):

```dart
    if (password.length < 6) {
      setState(
        () => _errorMessage = 'La contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }
```

por:

```dart
    final unmet = PasswordPolicy.unmet(password);
    if (unmet.isNotEmpty) {
      setState(
        () => _errorMessage =
            'La contraseña aún no cumple: '
            '${unmet.map(PasswordPolicy.labelFor).join(', ')}.',
      );
      return;
    }
```

Cambiar `final password = _passwordCtrl.text.trim();` (línea 59) y
`final confirm = _confirmCtrl.text.trim();` (línea 60) por sus versiones sin
`.trim()`, por la misma razón que en la Task 3:

```dart
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
```

Registrar los listeners en `initState` para que la lista se redibuje al
escribir (junto a la carga de datos existente, líneas 35-45):

```dart
    _passwordCtrl.addListener(_onPasswordChanged);
    _confirmCtrl.addListener(_onPasswordChanged);
```

y añadir el método:

```dart
  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }
```

Insertar el feedback justo después del campo "Confirmar Contraseña" (tras la
línea 269, antes del `SizedBox(height: context.r.spaceLg)` de la línea 271):

```dart
                    SizedBox(height: context.r.spaceMd),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 275),
                      child: PasswordFeedback(
                        password: _passwordCtrl.text,
                        confirm: _confirmCtrl.text,
                      ),
                    ),
```

Añadir los imports:

```dart
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/password_feedback.dart';
```

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/features/password_change_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Verificar y commitear**

```bash
flutter analyze
flutter test
git add lib/features/auth/screens/password_change_screen.dart test/features/password_change_screen_test.dart
git commit -m "fix: primer ingreso usa la misma política de contraseña que Perfil

Antes exigía solo 6 caracteres, así que se podía fijar en el primer ingreso
una contraseña que el diálogo de Perfil habría rechazado.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: `useSideNav` como única fuente de verdad

Hoy la regla está escrita dos veces —`tab_shell.dart:1732` y
`responsive_extensions.dart:163`— y en ninguna se consulta `kIsWeb`, de modo
que una tablet **nativa** en horizontal recibe la barra lateral.

**Files:**
- Modify: `lib/core/extensions/responsive_extensions.dart:160-173`
- Modify: `lib/shell/tab_shell.dart:1732-1733`
- Test: `test/core/use_side_nav_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `AppResponsive.useSideNav` → `bool`; constante de nivel de librería
  `kSideNavMinWidth` → `double` (900).

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/use_side_nav_test.dart`:

```dart
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
          reason: 'en $size la reserva debe coincidir con la posición de la barra',
        );
      }
    });
  });

  test('el umbral de navegación lateral es 900', () {
    expect(kSideNavMinWidth, 900);
  });
}
```

- [ ] **Step 2: Correr el test para verificar que falla**

Run: `flutter test test/core/use_side_nav_test.dart`
Expected: FAIL — `useSideNav` y `kSideNavMinWidth` no están definidos.

- [ ] **Step 3: Añadir `useSideNav` y hacer que `navBarBottomSpace` lo consuma**

En `lib/core/extensions/responsive_extensions.dart`, añadir tras los imports:

```dart
/// Ancho mínimo de ventana, solo en web, para pasar a navegación lateral.
///
/// 900 y no los 600 de `isTablet`: así una ventana de navegador a media
/// pantalla (500-800 px) conserva el aspecto móvil completo en vez de caer en
/// un híbrido que no es ni una cosa ni la otra.
const double kSideNavMinWidth = 900;
```

Dentro de `AppResponsive`, añadir junto a los demás flags de dispositivo
(después de `isLargePhone`, línea 77):

```dart
  /// Única fuente de verdad de la posición de la navegación.
  ///
  /// Solo la web con ventana ancha usa el SideNavBar. En nativo (Android/iOS),
  /// sea teléfono o tablet, vertical u horizontal, la barra va SIEMPRE abajo.
  /// La condición anterior (`isDesktop || (isTablet && isLandscape)`) no
  /// consultaba `kIsWeb`, así que una tablet nativa en horizontal perdía la
  /// barra inferior.
  bool get useSideNav => kIsWeb && screenWidth >= kSideNavMinWidth;
```

Reemplazar el cuerpo de `navBarBottomSpace` (líneas 162-173) para que consuma
la propiedad en lugar de reimplementar la regla:

```dart
  double get navBarBottomSpace {
    // Deriva de useSideNav: con navegación lateral no hay barra inferior que
    // esquivar. Antes esta condición estaba duplicada y podía divergir.
    if (useSideNav) return 0;
    // Derivado de la geometría REAL del FloatingNavBar en tab_shell
    // (Scaffold extendBody: el contenido se dibuja detrás de la barra):
    //   altura de la barra + separación inferior + inset del sistema,
    // más un margen de respiro (spaceLg) que también absorbe la sombra de la
    // barra (blur 15 se extiende ~10 px hacia arriba).
    final navInset = kIsWeb ? 4.0 : navBarBottomInset;
    return navBarHeight + navInset + viewPaddingBottom + spaceLg;
  }
```

En `lib/shell/tab_shell.dart`, reemplazar las líneas 1732-1733:

```dart
            final bool useSideNav =
                r.isDesktop || (r.isTablet && r.isLandscape);
```

por:

```dart
            final bool useSideNav = r.useSideNav;
```

- [ ] **Step 4: Correr el test para verificar que pasa**

Run: `flutter test test/core/use_side_nav_test.dart`
Expected: PASS — las cuatro pruebas nativas dan `false`, incluida la tablet
horizontal que antes daba `true`.

- [ ] **Step 5: Verificar y commitear**

```bash
flutter analyze
flutter test
git add lib/core/extensions/responsive_extensions.dart lib/shell/tab_shell.dart test/core/use_side_nav_test.dart
git commit -m "fix: las tablets nativas conservan la barra inferior

useSideNav estaba escrita dos veces (tab_shell y navBarBottomSpace) y en
ninguna se consultaba kIsWeb, así que una tablet Android/iOS en horizontal
recibía la barra lateral pensada para la web. Ahora es una sola propiedad
de AppResponsive: solo web con ventana >= 900 px usa navegación lateral.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: Arnés de auditoría de layout — infraestructura

Se construye **con las pantallas en su estado actual roto**, a propósito: su
primera corrida es la medición. Esta task entrega la maquinaria y la prueba
sobre un primer lote pequeño; la Task 7 completa el registro.

**Files:**
- Create: `test/support/responsive_harness.dart`
- Create: `test/responsive_audit_test.dart`
- Test: el propio `responsive_audit_test.dart`

**Interfaces:**
- Consumes: `AppResponsive` (Task 5).
- Produces:
  - `class AuditViewport { final String name; final Size size; }`
  - `const List<AuditViewport> kAuditViewports`
  - `class ScreenCase { final String name; final Widget Function() build; final bool hasTextInput; final String? excludedReason; }`
  - `Future<void> auditScreen(WidgetTester tester, ScreenCase c, AuditViewport v, {required bool keyboard})`
  - `void setUpHarness()` — binding, secure storage, sonido, sesión sembrada.
  - `const UserModel kTestUser`

- [ ] **Step 1: Escribir el arnés**

Crear `test/support/responsive_harness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/models/user_model.dart';
import 'package:cossmil/core/session/user_session.dart';
import 'package:cossmil/core/theme/sound_manager.dart';

/// Un tamaño de pantalla de la matriz de auditoría.
///
/// Se llama AuditViewport y no Viewport porque `material.dart` ya exporta un
/// widget `Viewport`: el nombre corto colisiona y no compila.
class AuditViewport {
  final String name;
  final Size size;
  const AuditViewport(this.name, this.size);

  @override
  String toString() => '$name (${size.width.toInt()}x${size.height.toInt()})';
}

/// Los 6 tamaños que deben quedar impecables.
const List<AuditViewport> kAuditViewports = [
  AuditViewport('phoneSmall', Size(320, 568)), // iPhone SE / Android gama baja
  AuditViewport('phoneMedium', Size(375, 812)), // iPhone 13 mini
  AuditViewport('phoneLarge', Size(430, 932)), // iPhone Pro Max
  AuditViewport('tabletPortrait', Size(768, 1024)), // SM-T735 vertical
  AuditViewport('tabletLandscape', Size(1024, 768)), // SM-T735 horizontal
  AuditViewport('desktop', Size(1440, 900)), // web nginx:8080
];

/// Alto típico del teclado. Es lo que revienta las pantallas sin scroll.
const double kKeyboardInset = 336;

/// Una pantalla registrada en la auditoría.
class ScreenCase {
  final String name;
  final Widget Function() build;

  /// Si tiene campos de texto, también se audita con el teclado abierto.
  final bool hasTextInput;

  /// Si no es null, la pantalla se OMITE y el motivo se reporta. Usar solo
  /// cuando montarla en test es inviable (plugin nativo sin mock).
  final String? excludedReason;

  const ScreenCase(
    this.name,
    this.build, {
    this.hasTextInput = false,
    this.excludedReason,
  });
}

const UserModel kTestUser = UserModel(
  id: '4821',
  fullName: 'Juan Carlos Perez Mamani',
  rank: 'CORONEL',
  matricula: 'M-12345',
  bloodType: 'O+',
  age: 44,
  gender: 'M',
  role: 'titular',
  isEnabled: true,
  ci: '1234567',
  fuerza: 'EJERCITO',
  birthDate: '1981-05-14',
  numCel: '71292794',
  beneficiaries: [],
);

/// Binding, storage falso, sonido apagado y sesión sembrada.
void setUpHarness() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // audioplayers deja timers pendientes que hacen fallar el teardown.
  SoundManager.soundEnabledNotifier.value = false;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    UserSession.currentUser = kTestUser;
  });

  tearDown(UserSession.clear);
}

/// Monta [c] en [v] y falla si el layout lanza cualquier excepción.
Future<void> auditScreen(
  WidgetTester tester,
  ScreenCase c,
  AuditViewport v, {
  required bool keyboard,
}) async {
  tester.view.physicalSize = v.size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: v.size,
        viewInsets: EdgeInsets.only(bottom: keyboard ? kKeyboardInset : 0),
      ),
      child: MaterialApp(home: c.build()),
    ),
  );

  // NUNCA pumpAndSettle: login, la instructora del tutorial y el carnet tienen
  // animaciones en bucle que jamás asientan. Frames acotados bastan para que
  // el layout se resuelva y los overflows se disparen.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason:
        '${c.name} desborda en $v '
        '${keyboard ? "CON teclado" : "sin teclado"}:\n$exception',
  );
}

/// Genera el grupo de pruebas para un lote de pantallas.
void auditGroup(String groupName, List<ScreenCase> cases) {
  group(groupName, () {
    for (final c in cases) {
      if (c.excludedReason != null) {
        // Una exclusión NO desaparece en silencio: queda como test omitido con
        // su motivo visible en la salida.
        test(c.name, () {}, skip: 'EXCLUIDA: ${c.excludedReason}');
        continue;
      }
      for (final v in kAuditViewports) {
        testWidgets('${c.name} · $v', (tester) async {
          await auditScreen(tester, c, v, keyboard: false);
        });
        if (c.hasTextInput) {
          testWidgets('${c.name} · $v · teclado', (tester) async {
            await auditScreen(tester, c, v, keyboard: true);
          });
        }
      }
    }
  });
}
```

- [ ] **Step 2: Registrar el primer lote (auth) y correr**

Crear `test/responsive_audit_test.dart`:

```dart
import 'package:cossmil/features/auth/screens/login_screen.dart';
import 'package:cossmil/features/auth/screens/pin_setup_screen.dart';
import 'package:cossmil/features/auth/screens/pin_verify_screen.dart';
import 'package:cossmil/features/auth/screens/password_change_screen.dart';

import 'support/responsive_harness.dart';

/// Auditoría de layout: cada pantalla en 6 viewports, con y sin teclado.
/// Falla ante cualquier RenderFlex overflow o assertion de layout.
///
/// Para añadir una pantalla nueva: una línea en la lista de abajo.
void main() {
  setUpHarness();

  auditGroup('auth', [
    ScreenCase('LoginScreen', LoginScreen.new, hasTextInput: true),
    ScreenCase('PinSetupScreen', PinSetupScreen.new),
    ScreenCase('PinVerifyScreen', PinVerifyScreen.new),
    ScreenCase(
      'PasswordChangeScreen',
      PasswordChangeScreen.new,
      hasTextInput: true,
    ),
  ]);
}
```

Run: `flutter test test/responsive_audit_test.dart`
Expected: **FAIL en varios casos.** `PinSetupScreen` y `PinVerifyScreen` no
tienen scroll (medido) y deberían desbordar al menos en `phoneSmall`. Un
resultado todo-verde aquí significa que el arnés no está midiendo — revisar que
`tester.takeException()` se consulte y que el `MediaQuery` externo realmente
llegue a la pantalla.

Si algún constructor no coincide (p. ej. `PinVerifyScreen` exige parámetros),
comprobar la firma con `grep -n "const PinVerifyScreen" lib/features/auth/screens/pin_verify_screen.dart`
y envolver en un closure: `ScreenCase('PinVerifyScreen', () => const PinVerifyScreen(motivo: '...'))`.

- [ ] **Step 3: Registrar los fallos como línea base**

Ejecutar y guardar la salida:

```bash
flutter test test/responsive_audit_test.dart --reporter expanded 2>&1 | tee /tmp/audit-auth.txt
```

Crear `docs/superpowers/plans/2026-08-12-auditoria-linea-base.md` con una tabla:
pantalla, viewport, con/sin teclado, excepción. Esta tabla es el insumo de las
Tasks 8-11.

- [ ] **Step 4: Commitear el arnés con los fallos visibles**

El arnés se commitea **rojo**, a propósito: documenta el estado real antes de
arreglar. Se marca para que CI no lo tome como regresión — añadir al principio
de `responsive_audit_test.dart`:

```dart
// NOTA: este archivo está ROJO a propósito hasta completar las tasks 8-11.
// Cada fallo es un defecto de layout real, catalogado en
// docs/superpowers/plans/2026-08-12-auditoria-linea-base.md
```

```bash
git add test/support/responsive_harness.dart test/responsive_audit_test.dart docs/superpowers/plans/2026-08-12-auditoria-linea-base.md
git commit -m "test: arnés de auditoría de layout (6 viewports x teclado)

Se commitea en rojo a propósito: cada fallo es un defecto real, catalogado
en la línea base. Sin esta medición, 'mejorar la responsividad' es un juicio
estético infinito y no verificable.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: Completar el registro de pantallas

Extiende el arnés a las 48 pantallas y a los modales de pantalla completa. Es la
parte más costosa (sembrar datos para cada una) y donde puede aparecer trabajo
imprevisto.

**Files:**
- Modify: `test/responsive_audit_test.dart`
- Modify: `test/support/responsive_harness.dart` (sembrado de `AppSessionCache`)
- Modify: `docs/superpowers/plans/2026-08-12-auditoria-linea-base.md`

**Interfaces:**
- Consumes: todo lo de la Task 6.
- Produces: `seedSessionCache()` en el arnés — precarga `AppSessionCache` con
  regionales, especialidades, grupo familiar y fecha de servidor de prueba.

- [ ] **Step 1: Añadir el sembrado de `AppSessionCache`**

Comprobar primero la forma real de la caché:

```bash
grep -n "static.*List\|static bool isLoaded\|static.*fechaServidor" lib/core/data/app_session_cache.dart
```

Añadir a `test/support/responsive_harness.dart` una función `seedSessionCache()`
que asigne una lista de un elemento a cada campo y ponga `isLoaded = true`,
usando los modelos reales. Llamarla desde el `setUp` de `setUpHarness()`.

- [ ] **Step 2: Registrar los grupos restantes**

Añadir a `test/responsive_audit_test.dart` un `auditGroup` por feature, con
todas las pantallas de `lib/features/*/screens/` más los modales de pantalla
completa de `core/widgets/` y `shell/widgets/`. Grupos: `auth` (ya está),
`home`, `booking`, `reservas`, `calendario`, `carnet`, `perfil`, `familia`,
`procedimientos`, `notificaciones`, `loading`, `splash`, `modales`.

Marcar `hasTextInput: true` en toda pantalla con `CupertinoTextField` o
`TextField`. Localizarlas con:

```bash
grep -rln "CupertinoTextField\|TextField(" lib/features lib/core/widgets lib/shell
```

Toda pantalla que no se pueda montar se registra con `excludedReason` y su
motivo concreto — nunca se omite en silencio.

- [ ] **Step 3: Correr la auditoría completa y ampliar la línea base**

```bash
flutter test test/responsive_audit_test.dart --reporter expanded 2>&1 | tee /tmp/audit-full.txt
```

Volcar todos los fallos a la tabla de
`docs/superpowers/plans/2026-08-12-auditoria-linea-base.md`, agrupados por
categoría: (A) scroll/teclado, (B) widget fuera del sistema responsive,
(C) tipografía hardcodeada, (D) `Row`/`Text` sin `Flexible`.

- [ ] **Step 4: Commitear**

```bash
git add test/ docs/superpowers/plans/2026-08-12-auditoria-linea-base.md
git commit -m "test: registro completo de pantallas en la auditoría de layout

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: Categoría A — scroll y teclado

Las 9 pantallas sin ningún widget de scroll (medido): `splash`,
`account_unlock`, `local_auth`, `pin_setup`, `pin_verify`, `save_account`,
`booking_flow`, `carnet_salud`, `carnet_validador`.

**Files:**
- Modify: las pantallas de la categoría A de la línea base
- Test: `test/responsive_audit_test.dart` (sin cambios; debe pasar a verde)

**Interfaces:**
- Consumes: la línea base de la Task 7.
- Produces: nada.

- [ ] **Step 1: Confirmar los fallos de la categoría A**

```bash
flutter test test/responsive_audit_test.dart --plain-name "teclado" --reporter expanded
```

- [ ] **Step 2: Aplicar el patrón de scroll**

Para una pantalla cuyo cuerpo es un `Column` sin `Expanded`/`Spacer`:

```dart
// Antes
body: SafeArea(child: Column(children: [...])),

// Después
body: SafeArea(
  child: SingleChildScrollView(
    physics: const ClampingScrollPhysics(),
    // El teclado empuja el contenido en vez de recortarlo.
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(children: [...]),
  ),
),
```

Si el `Column` **sí** usa `Expanded`/`Spacer` (centrado vertical), hace falta
conservar la altura mínima:

```dart
body: SafeArea(
  child: LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        // IntrinsicHeight SOLO aquí: Expanded/Spacer necesitan una altura
        // acotada, que el scroll no da. Es costoso, no usarlo si no hay flex.
        child: IntrinsicHeight(child: Column(children: [...])),
      ),
    ),
  ),
),
```

**No** añadir padding fijo para "compensar" el teclado: eso rompe en cuanto el
teclado tiene otra altura.

- [ ] **Step 3: Verificar que la categoría A queda verde**

Run: `flutter test test/responsive_audit_test.dart`
Expected: los casos de scroll/teclado pasan. Las categorías B/C/D pueden seguir
rojas.

- [ ] **Step 4: Commitear**

```bash
flutter analyze
git add lib/features/ && git commit -m "fix: las pantallas sin scroll ya no desbordan con el teclado abierto

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: Categoría B — widgets compartidos al sistema responsive

Los 17 archivos medidos fuera de `context.r`. Se excluyen `carnet_pdf.dart`
(genera PDF, no UI de pantalla), `carnet_data.dart` y `tramite_catalog.dart`
(datos puros): quedan **14** widgets reales.

**Files:**
- Modify: `lib/core/widgets/`: `cossmil_loader.dart`, `familia_help_dialog.dart`,
  `guided_tap_hint.dart`, `image_banner.dart`, `liquid_glass.dart`,
  `loader_with_message.dart`, `tutorial_flow_host.dart`, `tutorial_instructor.dart`,
  `tutorial_invite_dialog.dart`, `app_background.dart`
- Modify: `lib/shell/widgets/side_nav_bar.dart`
- Modify: `lib/features/carnet/widgets/carnet_card.dart`, `holographic_card.dart`
- Modify: `lib/features/home/widgets/coming_soon_dialog.dart`

**Interfaces:**
- Consumes: `AppResponsive`, `ResponsiveTypography`.
- Produces: nada.

- [ ] **Step 1: Sustituir literales por tokens, archivo por archivo**

Mapa de conversión (usar el token cuyo valor en `phoneMedium` coincide con el
literal actual, para no alterar la apariencia en el tamaño de referencia):

| Literal | Token |
|---|---|
| `EdgeInsets.all(16)` | `EdgeInsets.all(context.r.spaceMd)` |
| `SizedBox(height: 24)` | `SizedBox(height: context.r.spaceLg)` |
| `BorderRadius.circular(16)` | `BorderRadius.circular(context.r.cardRadius)` |
| `Icon(..., size: 24)` | `Icon(..., size: context.r.iconMd)` |
| `height: 52` (botón) | `height: context.r.buttonHeight` |

**Excepción deliberada:** `carnet_card.dart` y `holographic_card.dart` dibujan
un carnet con proporciones de tarjeta física (ISO 7810). Sus medidas internas
**no** deben volverse responsive: se escala la tarjeta entera con `FittedBox` y
se deja intacta su geometría interna. Convertir sus literales a tokens rompería
las proporciones.

- [ ] **Step 2: Verificar que no cambió la apariencia en el tamaño de referencia**

Run: `flutter test`
Expected: los tests existentes (`carnet_screen_test.dart`, 110+ casos) siguen
verdes. Si uno falla por geometría, el cambio alteró el diseño: revertir ese
archivo y anotarlo.

- [ ] **Step 3: Correr la auditoría**

Run: `flutter test test/responsive_audit_test.dart`
Expected: la categoría B queda verde.

- [ ] **Step 4: Commitear**

```bash
flutter analyze
git add lib/ && git commit -m "refactor: los widgets compartidos usan el sistema responsive

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: Categoría C — tipografía hardcodeada

~120 `fontSize:` literales medidos. Los mayores focos: `perfil_screen` (23),
`carnet_salud_screen` (16), `carnet_card` (15), `active_appointment_modal` (13),
`carnet_validador_screen` (8), `notificaciones_screen` (6).

**Files:**
- Modify: los archivos listados por
  `grep -rn "fontSize: [0-9]" lib/features lib/shell lib/core/widgets --include=*.dart`
  (excluyendo `carnet_pdf.dart`, que genera PDF con puntos tipográficos, no
  píxeles de pantalla)

**Interfaces:**
- Consumes: `ResponsiveTypography` vía `context.texts`.
- Produces: nada.

- [ ] **Step 1: Convertir según la tabla de equivalencias**

Se elige el estilo cuyo tamaño en `phoneMedium` coincide con el literal:

| `fontSize:` | Estilo |
|---|---|
| 10-11 | `context.texts.labelSmall` |
| 12 | `context.texts.bodySmall` |
| 14 | `context.texts.bodyMedium` |
| 15 | `context.texts.bodyLarge` / `titleMedium` |
| 17 | `context.texts.titleLarge` |
| 20 | `context.texts.headlineMedium` |
| 24 | `context.texts.headlineLarge` |
| 32 | `context.texts.displayLarge` |

Forma:

```dart
// Antes
style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c),

// Después — copyWith conserva peso y color; el tamaño pasa a ser responsive.
style: context.texts.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: c),
```

Igual que en la Task 9, `carnet_card.dart` es la excepción: su tipografía es
parte de la geometría de la tarjeta.

- [ ] **Step 2: Verificar**

Run: `flutter analyze && flutter test`
Expected: todo verde; los tests de carnet no se mueven.

- [ ] **Step 3: Commitear**

```bash
git add lib/ && git commit -m "refactor: tipografía por tokens en vez de fontSize literales

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: Categoría D — `Row`/`Text` sin `Flexible`

El defecto que recorta nombres largos de médicos y especialidades.

**Files:**
- Modify: los archivos de la categoría D de la línea base

**Interfaces:**
- Consumes: la línea base de la Task 7.
- Produces: nada.

- [ ] **Step 1: Aplicar el patrón**

```dart
// Antes — el texto empuja fuera de la fila y desborda.
Row(children: [Icon(icon), SizedBox(width: 8), Text(nombreLargo)])

// Después — el texto cede espacio y elide.
Row(
  children: [
    Icon(icon),
    SizedBox(width: context.r.spaceSm),
    Expanded(
      child: Text(nombreLargo, overflow: TextOverflow.ellipsis),
    ),
  ],
)
```

Usar `Flexible` en vez de `Expanded` cuando el texto **no** deba ocupar el
sobrante (p. ej. un texto seguido de un chip que debe quedar pegado).

- [ ] **Step 2: Verificar que la auditoría queda entera en verde**

Run: `flutter test test/responsive_audit_test.dart`
Expected: **PASS completo** (salvo las exclusiones declaradas).

- [ ] **Step 3: Quitar la nota de "rojo a propósito"**

Borrar de `test/responsive_audit_test.dart` el comentario `// NOTA: este archivo
está ROJO a propósito…` añadido en la Task 6, ya no vigente.

- [ ] **Step 4: Commitear**

```bash
flutter analyze && flutter test
git add lib/ test/ && git commit -m "fix: los textos largos ceden espacio en vez de desbordar

Con esto la auditoría de layout queda entera en verde.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: Verificación final

**Files:**
- Modify: `CLAUDE.md` (documentar el arnés y `useSideNav`)

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: nada.

- [ ] **Step 1: Suite completa**

```bash
flutter analyze
flutter test
```
Expected: analyze sin issues; toda la suite verde, exclusiones declaradas
visibles como `skip` con motivo.

- [ ] **Step 2: Verificación manual en web**

```bash
flutter run -d chrome
```

Comprobar redimensionando la ventana:
- ancho ≥ 900 px → navegación **lateral**;
- ancho < 900 px → navegación **inferior**, sin contenido tapado;
- Perfil → Cambiar Contraseña: escribir `Militar-2026` y ver los 5 tildes
  aparecer uno a uno, la barra llegar a "Fuerte", y el botón habilitarse.

- [ ] **Step 3: Verificación manual en el dispositivo**

```bash
flutter run -d <id-de-la-tablet>
```

Girar la SM-T735 a horizontal y confirmar que la barra **sigue abajo** (antes
saltaba a lateral). Recordar que un `adb install` reemplaza la app instalada:
la sesión de login no sobrevive.

- [ ] **Step 4: Documentar en CLAUDE.md**

Añadir a la sección "Responsive Layout":

```markdown
- `AppResponsive.useSideNav` es la ÚNICA fuente de verdad de la posición de la
  navegación: solo web con ventana ≥ `kSideNavMinWidth` (900 px) usa el
  SideNavBar. En nativo la barra va siempre abajo. `navBarBottomSpace` deriva
  de esta propiedad — no reimplementar la condición.
- `test/responsive_audit_test.dart` monta cada pantalla en 6 viewports (320 →
  1440 px), con y sin teclado, y falla ante cualquier overflow. Registrar toda
  pantalla nueva ahí: es una línea en `auditGroup`.
```

Y a "Security Layer":

```markdown
- `PasswordPolicy` (`core/utils/password_policy.dart`) es el único validador de
  contraseña, compartido por el sheet de Perfil y el primer ingreso. Especial =
  cualquier carácter no alfanumérico (acentos y ñ cuentan como letras).
```

- [ ] **Step 5: Commitear**

```bash
git add CLAUDE.md
git commit -m "docs: documenta el arnés de auditoría y la política de contraseña

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Notas de riesgo

- **Task 7 es la de mayor incertidumbre.** Sembrar datos para 48 pantallas puede
  destapar dependencias no previstas (plugins nativos, servicios que llaman a
  red en `initState`). El escape está previsto: `excludedReason` con motivo
  visible. Lo que no se admite es omitir en silencio.
- **El backend puede rechazar caracteres especiales** que `PasswordPolicy`
  acepta. Por eso la Task 3 saca el mensaje real del servidor a la superficie.
  Deliberadamente no se restringe el set local a ciegas: eso reintroduciría el
  bug que se está arreglando.
- **Tasks 9 y 10 pueden alterar la apariencia** si un literal no se mapea al
  token equivalente. La red de seguridad son los 110+ tests existentes; si uno
  falla por geometría, revertir ese archivo antes que ajustar el test.
