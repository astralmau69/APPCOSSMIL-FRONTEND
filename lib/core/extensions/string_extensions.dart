/// Extensiones de String para normalización de textos del backend.
///
/// El backend envía nombres, regionales, hospitales, especialidades, etc.
/// en MAYÚSCULAS completas. Esta extensión centraliza la conversión a
/// Title Case para presentación en la UI.
extension StringDisplay on String {
  /// Convierte un texto a Title Case para display.
  ///
  /// - "JUAN PEREZ MAMANI" → "Juan Perez Mamani"
  /// - "HOSPITAL MILITAR CENTRAL" → "Hospital Militar Central"
  /// - "MEDICINA GENERAL" → "Medicina General"
  /// - "" → ""
  ///
  /// Limpia espacios múltiples y hace trim.
  /// Siempre convierte: primera letra mayúscula, resto minúscula por palabra.
  String get toDisplayCase {
    final cleaned = replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';

    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
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
