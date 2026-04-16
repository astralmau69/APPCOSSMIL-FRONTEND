/// Utilidades para formateo de rangos militares y prefijos de tratamiento.
///
/// Centraliza la lógica de abreviación de grados y los prefijos
/// (Sr./Sra./Joven/Srta.) que se muestran delante de los nombres.
class RankUtils {
  RankUtils._();

  // ── Abreviaciones de rangos militares bolivianos ─────────────────────────

  static const _abbreviations = <String, String>{
    // ── Ejército de Bolivia ───────────────────────────────────────────────
    'GENERAL DE DIVISION': 'Grl. Div.',
    'GENERAL DE BRIGADA': 'Grl. Brig.',
    'GENERAL': 'Grl.',
    'CORONEL': 'Cnl.',
    'TENIENTE CORONEL': 'Tte. Cnl.',
    'MAYOR': 'My.',
    'CAPITAN': 'Cap.',
    'TENIENTE': 'Tte.',
    'SUBTENIENTE': 'Sbtte.',
    'SARGENTO MAYOR': 'Sgto. My.',
    'SARGENTO PRIMERO': 'Sgto. 1ro.',
    'SARGENTO SEGUNDO': 'Sgto. 2do.',
    'CABO': 'Cbo.',
    'SOLDADO': 'Sdo.',
    // ── Armada Boliviana ──────────────────────────────────────────────────
    'ALMIRANTE': 'Almte.',
    'VICEALMIRANTE': 'V. Almte.',
    'CONTRAALMIRANTE': 'C. Almte.',
    'CAPITAN DE NAVIO': 'Cap. Nav.',
    'CAPITAN DE FRAGATA': 'Cap. Frag.',
    'CAPITAN DE CORBETA': 'Cap. Corb.',
    'TENIENTE DE NAVIO': 'Tte. Nav.',
    'TENIENTE DE FRAGATA': 'Tte. Frag.',
    'ALFEREZ DE NAVIO': 'Alf. Nav.',
    'MARINERO': 'Mar.',
    // ── Fuerza Aérea Boliviana ────────────────────────────────────────────
    'GENERAL DE AVIACION': 'Grl. Av.',
    'GENERAL DE DIVISION AEREA': 'Grl. Div.',
    'GENERAL DE BRIGADA AEREA': 'Grl. Brig.',
  };

  /// Abrevia un grado militar. Ej: "CORONEL" → "Cnl."
  ///
  /// Si no se encuentra el grado en la tabla, retorna la primera palabra
  /// capitalizada con punto. Si el grado está vacío, retorna vacío.
  static String abbreviateRank(String grado) {
    if (grado.isEmpty) return '';

    final upper = grado.trim().toUpperCase();
    if (upper.isEmpty) return '';

    // Buscar coincidencia exacta
    final exact = _abbreviations[upper];
    if (exact != null) return exact;

    // Buscar coincidencia parcial (ej: "Coronel de" → "Cnl.")
    for (final entry in _abbreviations.entries) {
      if (upper.startsWith(entry.key)) return entry.value;
    }

    // Fallback: primera palabra capitalizada
    final first = upper.split(' ').first;
    return '${first[0]}${first.substring(1).toLowerCase()}.';
  }

  // ── Prefijo de tratamiento para beneficiarios ────────────────────────────

  /// Retorna el prefijo de tratamiento para un beneficiario (no titular).
  ///
  /// - Menor de 18 años: sin prefijo (retorna vacío).
  /// - 18 años o más: "Sr." / "Sra."
  ///
  /// [gender] puede ser "MASCULINO", "FEMENINO", "M", "F", etc.
  static String beneficiaryPrefix({required int? age, required String gender}) {
    final g = gender.trim().toUpperCase();
    final isFemale = g == 'FEMENINO' || g == 'F';
    final actualAge = age ?? 0;

    // Menores de 18: sin prefijo
    if (actualAge > 0 && actualAge < 18) return '';

    // 18 años en adelante: tratamiento formal
    return isFemale ? 'Sra.' : 'Sr.';
  }

  // ── Nombre con prefijo combinado ─────────────────────────────────────────

  /// Genera el nombre con prefijo apropiado:
  /// - Titular: rango abreviado + nombre
  /// - Beneficiario: Sr./Sra./Joven/Srta. + nombre
  static String displayNameWithPrefix({
    required String fullName,
    required bool isTitular,
    required String grado,
    required int? age,
    required String gender,
  }) {
    if (fullName.isEmpty) return fullName;

    if (isTitular && grado.isNotEmpty) {
      if (grado.toLowerCase() == 'asegurado') return fullName;
      // La API ya devuelve el grado abreviado (ej: "CNL.").
      // Solo limpiamos el doble punto que podría aparecer por datos legacy.
      final cleanGrado = grado.trim().replaceAll('..', '.');
      return cleanGrado.isNotEmpty ? '$cleanGrado $fullName' : fullName;
    }

    if (!isTitular) {
      final prefix = beneficiaryPrefix(age: age, gender: gender);
      return prefix.isEmpty ? fullName : '$prefix $fullName';
    }

    return fullName;
  }

  // ── Estado de servicio ───────────────────────────────────────────────────

  /// Retorna la etiqueta de estado de servicio.
  /// "ACTIVO" → "Servicio Activo", cualquier otro → "Servicio Pasivo"
  static String serviceStatusLabel(String refe4) {
    final upper = refe4.trim().toUpperCase();
    return upper == 'ACTIVO' ? 'Servicio Activo' : 'Servicio Pasivo';
  }

  /// `true` si el estado es activo.
  static bool isServiceActive(String refe4) {
    return refe4.trim().toUpperCase() == 'ACTIVO';
  }
}
