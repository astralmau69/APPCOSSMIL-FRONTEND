import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cossmil/core/constants/app_sounds.dart';

/// Red de seguridad del catálogo de sonidos.
///
/// `SoundManager.playUi` traga cualquier excepción a propósito (un fallo de
/// audio jamás debe romper la interfaz), así que una ruta mal escrita o un
/// asset que no se declaró en el pubspec NO fallaría en tiempo de ejecución:
/// simplemente se quedaría mudo para siempre. Esto lo detecta en CI.
void main() {
  const catalog = <String, String>{
    'tap': AppSounds.tap,
    'nav': AppSounds.nav,
    'select': AppSounds.select,
    'back': AppSounds.back,
    'toggleOn': AppSounds.toggleOn,
    'toggleOff': AppSounds.toggleOff,
    'sheet': AppSounds.sheet,
    'coach': AppSounds.coach,
    'advance': AppSounds.advance,
    'success': AppSounds.success,
    'welcome': AppSounds.welcome,
    'error': AppSounds.error,
    'alert': AppSounds.alert,
  };

  test('cada sonido del catálogo existe como asset', () {
    final faltantes = <String>[];
    catalog.forEach((nombre, ruta) {
      // Las rutas del catálogo son relativas a assets/ (así las consume
      // AssetSource de audioplayers).
      if (!File('assets/$ruta').existsSync()) faltantes.add('$nombre → $ruta');
    });
    expect(faltantes, isEmpty, reason: 'Assets de sonido ausentes: $faltantes');
  });

  test('assets/sounds/ está declarado en el pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/sounds/'));
  });

  test('no hay dos entradas del catálogo apuntando al mismo archivo', () {
    final rutas = catalog.values.toList();
    expect(rutas.toSet().length, rutas.length);
  });
}
