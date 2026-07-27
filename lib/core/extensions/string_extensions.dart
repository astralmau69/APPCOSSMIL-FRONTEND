/// Extensiones de String para normalización de textos del backend.
///
/// El backend envía nombres, regionales, hospitales, especialidades, etc.
/// en MAYÚSCULAS completas. Esta extensión centraliza la conversión a
/// Title Case para presentación en la UI, restaurando tildes y mayúsculas
/// correctas en palabras conocidas (REPORTE 004, 005, 008).
extension StringDisplay on String {
  /// Convierte un texto a Title Case para display.
  ///
  /// - "JUAN PEREZ MAMANI"  → "Juan Pérez Mamani"
  /// - "HOSPITAL MILITAR CENTRAL" → "Hospital Militar Central"
  /// - "CARDIOLOGIA"  → "Cardiología"
  /// - "" → ""
  ///
  /// Limpia espacios múltiples y hace trim.
  /// Aplica correcciones de tildes/ortografía para palabras del dominio médico
  /// y nombres geográficos bolivianos conocidos.
  String get toDisplayCase {
    // Pre-procesar: separar palabras donde una secuencia de MAYÚSCULAS se une
    // directamente con minúsculas (ej. "PEREZmamani" → "PEREZ mamani").
    // Esto ocurre cuando el backend concatena apellido paterno y materno sin espacio.
    final preProcessed = replaceAllMapped(
      RegExp(r'([A-Z]{2,})([a-z]{2,})'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    final cleaned = preProcessed.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';

    final words = cleaned.split(' ');
    final result = words
        .map((word) {
          if (word.isEmpty) return word;
          final raw = word[0].toUpperCase() + word.substring(1).toLowerCase();
          return _applyAccents(raw);
        })
        .join(' ');

    // Post-process multi-word corrections (e.g. "Ii" → "II" for ordenals)
    return _postProcessMultiWord(result);
  }

  /// Aplica correcciones de tildes a una palabra en Title Case.
  static String _applyAccents(String word) {
    return _accentMap[word] ?? word;
  }

  /// Correcciones de cuerpo completo (oraciones).
  static String _postProcessMultiWord(String text) {
    for (final entry in _phraseMap.entries) {
      // Replace ignoring case
      final pattern = RegExp(RegExp.escape(entry.key), caseSensitive: false);
      text = text.replaceAllMapped(pattern, (_) => entry.value);
    }
    return text;
  }

  // ─── Mapa de correcciones de palabras individuales ───────────────────────
  static const _accentMap = <String, String>{
    // ── Especialidades médicas (REPORTE 008) ──
    'Cardiologia': 'Cardiología',
    'Dermatologia': 'Dermatología',
    'Endocrinologia': 'Endocrinología',
    'Gastroenterologia': 'Gastroenterología',
    'Ginecologia': 'Ginecología',
    'Hematologia': 'Hematología',
    'Neumologia': 'Neumología',
    'Neurologia': 'Neurología',
    'Oftalmologia': 'Oftalmología',
    'Oncologia': 'Oncología',
    'Psicologia': 'Psicología',
    'Psiquiatria': 'Psiquiatría',
    'Reumatologia': 'Reumatología',
    'Traumatologia': 'Traumatología',
    'Urologia': 'Urología',
    'Odontologia': 'Odontología',
    'Radiologia': 'Radiología',
    'Ortopedia': 'Ortopedia',
    'Pediatria': 'Pediatría',
    'Nutricion': 'Nutrición',
    'Rehabilitacion': 'Rehabilitación',
    'Anestesiologia': 'Anestesiología',
    'Infectologia': 'Infectología',
    'Nefrologia': 'Nefrología',
    'Cirugia': 'Cirugía',
    'Otorrinolaringologia': 'Otorrinolaringología',
    'Endoscopia': 'Endoscopía',
    'Ecografia': 'Ecografía',
    'Atencion': 'Atención',
    'Medica': 'Médica',
    'Medico': 'Médico',
    'Medicos': 'Médicos',

    // ── Nombres geográficos (REPORTE 005) ──
    'Potosi': 'Potosí',
    'Mexico': 'México',
    'Cochabamba': 'Cochabamba',
    'Oruro': 'Oruro',
    'Sucre': 'Sucre',
    'Tarija': 'Tarija',
    'Trinidad': 'Trinidad',
    'Ayacucho': 'Ayacucho',
    'Villamontes': 'Villamontes',

    // ── Nombres propios comunes (REPORTE 005) ──
    'German': 'Germán',
    'Hernan': 'Hernán',
    'Belen': 'Belén',
    'Fatima': 'Fátima',
    'Tomas': 'Tomás',
    'Martin': 'Martín',
    'Ramon': 'Ramón',
    'Ruben': 'Rubén',
    'Dario': 'Darío',
    'Julio': 'Julio',
    'Marcelo': 'Marcelo',
    'Ivan': 'Iván',
    'Hector': 'Héctor',
    'Serafin': 'Serafín',
    'Wilfredo': 'Wilfredo',
    'Sarha': 'Sarha',
    'Juan': 'Juan',
    'Ferroviaria': 'Ferroviaria',
    'Vanguardia': 'Vanguardia',

    // ── Preposiciones / artículos (siempre minúsculas) ──
    'De': 'de',
    'Del': 'del',
    'La': 'la',
    'El': 'el',
    'Los': 'los',
    'Las': 'las',
    'Y': 'y',
    'En': 'en',
    'A': 'a',
  };

  // ─── Mapa de frases completas ────────────────────────────────────────────
  static const _phraseMap = <String, String>{
    // Nombres geográficos con artículo (deben preservar mayúscula inicial)
    'la Paz': 'La Paz',
    // Nombres de agencias con "Héroes" (REPORTE 005)
    'Heroes del chaco': 'Héroes del Chaco',
    'Heroes': 'Héroes',
    // Numeración romana correcta
    ' Ii ': ' II ',
    ' Ii)': ' II)',
    ' Iii ': ' III ',
    ' Iv ': ' IV ',
    // N.º / Nro para numeración de hospitales
    'N.o ': 'N.º ',
    'Nro ': 'Nro. ',
    'Nro.': 'Nro.',
  };
}

/// Extensión nullable para uso seguro en campos opcionales.
extension NullableStringDisplay on String? {
  /// Versión null-safe de [toDisplayCase].
  /// Retorna string vacío si es null.
  String get toDisplayCase {
    if (this == null || this!.isEmpty) return '';
    return this!.toDisplayCase;
  }
}
