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
  /// Retorna vacío si el grado no se encuentra en la tabla de rangos conocidos.
  /// **No usa fallback** para evitar que códigos del backend como "EC" o "ASEGURADO"
  /// se traten como rangos militares.
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

    // Grado no reconocido → retornar vacío para que el caller use Sr./Sra.
    return '';
  }

  /// `true` si el grado corresponde a un rango militar boliviano conocido
  /// (busca en la tabla de nombres extensos: CORONEL, TENIENTE, etc.).
  ///
  /// Solo funciona con grados en extenso — para titulares cuyo backend envía
  /// el grado ya abreviado, usar [isValidRankForDisplay].
  static bool isKnownMilitaryRank(String grado) {
    return abbreviateRank(grado).isNotEmpty;
  }

  /// `true` si [rank] es un valor que PUEDE mostrarse como grado en la UI.
  ///
  /// Aplica tanto a:
  /// - Titulares cuyo backend envía el grado ya abreviado (ej. "CNL.", "MY.")
  /// - Beneficiarios con grado en extenso (ej. "CORONEL")
  ///
  /// Retorna `false` para códigos civiles del backend ("EC", "ASEGURADO", etc.)
  /// que no son rangos militares reales.
  static bool isValidRankForDisplay(String rank) {
    if (rank.isEmpty) return false;
    if (_isCivilianCode(rank)) return false;
    // Si es un rango conocido en extenso → válido
    if (isKnownMilitaryRank(rank)) return true;
    // Si tiene punto (ej. "CNL.", "TTE. CNL.") y no es código civil → asumir abreviatura válida
    if (rank.contains('.') && !_isCivilianCode(rank.replaceAll('.', '')))
      return true;
    // Cualquier otro valor desconocido → no mostrar
    return false;
  }

  /// `true` si el valor es un código civil del backend que NO debe usarse como
  /// prefijo de grado militar. Aplica a titulares cuyo backend envía el grado
  /// ya abreviado (ej. "CNL.") pero también puede enviar códigos como "EC".
  ///
  /// Códigos conocidos del backend de COSSMIL:
  ///   - `EC`  → Empleado Civil
  ///   - `ASEGURADO` → asegurado sin grado específico
  ///   - `EMPLEADO CIVIL` → variante en extenso
  static bool _isCivilianCode(String grado) {
    final upper = grado.trim().toUpperCase().replaceAll(
      RegExp(r'\.+$'),
      '',
    ); // quitar puntos finales
    const civilianCodes = {
      'EC',
      'ASEGURADO',
      'EMPLEADO CIVIL',
      'EMP CIVIL',
      'EMP. CIVIL',
      'CIVIL',
    };
    return civilianCodes.contains(upper);
  }

  /// Versión pública de [_isCivilianCode] para uso en pantallas.
  /// `true` si el `rank` corresponde a un empleado civil (EC, EMPLEADO CIVIL,
  /// CIVIL, etc.), valor que no es un rango militar pero sí información del
  /// titular que conviene mostrar como label separado.
  static bool isCivilianRank(String rank) => _isCivilianCode(rank);

  /// Texto legible para mostrar como label cuando el `rank` es un código civil.
  /// Normaliza todas las variantes ("EC", "EMP. CIVIL", etc.) a "Empleado Civil".
  /// Retorna vacío si el rank no es un código civil.
  static String civilianLabel(String rank) =>
      _isCivilianCode(rank) ? 'Empleado Civil' : '';

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

  /// Genera el nombre con prefijo apropiado según el tipo de persona:
  ///
  /// **Titular** (`isTitular = true`):
  /// - Si tiene grado militar → grado abreviado + nombre (ej: "Cnl. Juan Pérez")
  /// - Sin grado → nombre solo
  ///
  /// **Beneficiario** (`isTitular = false`):
  /// - Si el backend le asignó un `grado` propio → grado abreviado + nombre
  ///   (caso: esposo/a que también es militar)
  /// - Sin grado y mayor de 18 años → "Sr." / "Sra." + nombre
  /// - Sin grado y menor de 18 años → nombre solo (sin prefijo)
  ///
  /// **Importante:** el grado del titular nunca se hereda al beneficiario.
  /// El caller es responsable de pasar `grado = ''` para beneficiarios
  /// que no tienen grado propio.
  static String displayNameWithPrefix({
    required String fullName,
    required bool isTitular,
    required String grado,
    required int? age,
    required String gender,
  }) {
    if (fullName.isEmpty) return fullName;

    // ── Titular ────────────────────────────────────────────────────────────
    // Para titulares, el backend envía el grado ya abreviado (ej. "CNL.", "MY."),
    // por lo que se muestra directamente sin pasar por abbreviateRank.
    // Solo se filtra la lista negra de códigos civiles que el backend puede enviar.
    if (isTitular) {
      if (grado.isEmpty || _isCivilianCode(grado)) return fullName;
      final cleanGrado = grado.trim().replaceAll('..', '.');
      return '$cleanGrado $fullName';
    }

    // ── Beneficiario ───────────────────────────────────────────────────────
    // Caso 1: grado en extenso reconocido (ej. "CORONEL") → abreviar y usar.
    //   Aplica tanto al esposo/a también militar como al grado heredado del
    //   titular cuando viene en extenso desde el backend.
    if (grado.isNotEmpty && isKnownMilitaryRank(grado)) {
      final abbrev = abbreviateRank(grado);
      return abbrev.isNotEmpty ? '$abbrev $fullName' : fullName;
    }

    // Caso 2: grado ya abreviado y válido (ej. "Cnl.", "Tte. Cnl.") heredado
    //   del titular asociado al beneficiario. Se filtran códigos civiles ('EC',
    //   'ASEGURADO', etc.) para no usarlos como prefijo.
    if (grado.isNotEmpty && isValidRankForDisplay(grado)) {
      final cleanGrado = grado.trim().replaceAll('..', '.');
      return '$cleanGrado $fullName';
    }

    // Caso 3: sin grado válido → Sr./Sra. según edad
    final prefix = beneficiaryPrefix(age: age, gender: gender);
    return prefix.isEmpty ? fullName : '$prefix $fullName';
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
