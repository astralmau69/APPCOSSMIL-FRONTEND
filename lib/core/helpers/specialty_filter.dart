import 'package:flutter/foundation.dart';
import '../models/specialty_model.dart';

/// Filtro de especialidades por edad y género del usuario.
///
/// Reglas de negocio (basadas en `idesp`, nunca por nombre):
///   - `idesp = 16` (Pediatría): solo visible si edad <= 15
///   - `idesp = 31` (Ginecología): solo visible si género es FEMENINO y edad >= 13
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

      if (kDebugMode && (idesp == _idPediatria || idesp == _idGinecologia)) {
        debugPrint('🔎 SpecialtyFilter.apply: idesp=$idesp, age=$age, gender="$genderUpper"');
      }

      // Regla 1: Pediatría (16) — Máximo 15 años
      if (idesp == _idPediatria) {
        if (age > _edadMaxPediatria) {
          if (kDebugMode) debugPrint('   ❌ Ocultando Pediatría (edad=$age > $_edadMaxPediatria)');
          return false;
        }
      }

      // Regla 2: Ginecología (31) — Solo para Femenino >= 13 años
      if (idesp == _idGinecologia) {
        if (genderUpper == 'MASCULINO') {
          if (kDebugMode) debugPrint('   ❌ Ocultando Ginecología (género=$genderUpper)');
          return false;
        }
        // Femenino menor de 13 años: ocultar también
        if (age > 0 && age < 13) {
          if (kDebugMode) debugPrint('   ❌ Ocultando Ginecología (femenino menor de 13 años, edad=$age)');
          return false;
        }
      }

      return true;
    }).toList();
  }
}
