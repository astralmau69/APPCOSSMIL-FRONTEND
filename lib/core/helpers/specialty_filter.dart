import 'package:flutter/foundation.dart';
import '../models/specialty_model.dart';

/// Filtro de especialidades por edad y género del usuario.
///
/// Reglas de negocio:
///   - `idesp = 16` o nombre "PEDIATRIA" / "ODONTOPEDIATRIA": solo visible si edad <= 15
///   - `idesp = 31` o nombre "GINECOLOGIA": solo visible si género es FEMENINO y edad >= 13
///   - nombre "GERIATRIA": solo visible si edad >= 50
///
/// Uso:
/// ```dart
/// final filtered = SpecialtyFilter.apply(
///   specialties: rawList,
///   age: user.age,
///   gender: user.gender,
/// );
/// ```
class SpecialtyFilter {
  SpecialtyFilter._();

  static const int _idPediatria = 16;
  static const int _idGinecologia = 31;
  static const int _edadMaxPediatria = 15;
  static const int _edadMinGeriatria = 50;

  /// Filtra la lista de especialidades según edad y género.
  ///
  /// Retorna una nueva lista sin las especialidades que no corresponden
  /// al perfil del usuario. Si [age] o [gender] son nulos o vacíos,
  /// no aplica la regla correspondiente (fail-open).
  static List<SpecialtyModel> apply({
    required List<SpecialtyModel> specialties,
    required int age,
    required String gender,
  }) {
    final genderUpper = gender.toUpperCase().trim();

    return specialties.where((s) {
      final idesp = int.tryParse(s.id) ?? -1;
      final nameUpper = s.name.toUpperCase();

      if (kDebugMode &&
          (idesp == _idPediatria ||
              idesp == _idGinecologia ||
              nameUpper.contains('GERIATRIA') ||
              nameUpper.contains('ODONTOPEDIATRIA'))) {
        debugPrint(
          '🔎 SpecialtyFilter.apply: idesp=$idesp, name="${s.name}", age=$age, gender="$genderUpper"',
        );
      }

      // Regla 1: Pediatría y Odontopediatría — Máximo 15 años
      final isPediatria =
          idesp == _idPediatria ||
          nameUpper.contains('PEDIATRIA') ||
          nameUpper.contains('ODONTOPEDIATRIA');
      if (isPediatria) {
        if (age > _edadMaxPediatria) {
          if (kDebugMode)
            debugPrint(
              '   ❌ Ocultando $nameUpper (edad=$age > $_edadMaxPediatria)',
            );
          return false;
        }
      }

      // Regla 2: Ginecología (31) — Solo para Femenino >= 13 años
      final isGinecologia =
          idesp == _idGinecologia ||
          nameUpper.contains('GINECOLOGIA') ||
          nameUpper.contains('GINECOLOGÍA');
      if (isGinecologia) {
        if (genderUpper == 'MASCULINO') {
          if (kDebugMode)
            debugPrint('   ❌ Ocultando Ginecología (género=$genderUpper)');
          return false;
        }
        // Femenino menor de 13 años: ocultar también
        if (age > 0 && age < 13) {
          if (kDebugMode)
            debugPrint(
              '   ❌ Ocultando Ginecología (femenino menor de 13 años, edad=$age)',
            );
          return false;
        }
      }

      // Regla 3: Geriatría — Solo para >= 50 años
      final isGeriatria =
          nameUpper.contains('GERIATRIA') || nameUpper.contains('GERIATRÍA');
      if (isGeriatria) {
        if (age < _edadMinGeriatria) {
          if (kDebugMode)
            debugPrint(
              '   ❌ Ocultando Geriatría (edad=$age < $_edadMinGeriatria)',
            );
          return false;
        }
      }

      return true;
    }).toList();
  }
}
