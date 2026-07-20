import 'dart:convert';
import 'dart:typed_data';

import 'app_logger.dart';

/// Decodificador único de fotos que llegan del backend COSSMIL.
///
/// Los endpoints devuelven la foto en formatos heterogéneos según la versión
/// del servicio:
///  - Base64 estándar (a veces con saltos de línea, espacios o sin padding)
///  - Data URI: `data:image/jpeg;base64,/9j/...`
///  - Enteros CON SIGNO separados por coma: `"-1,-40,120,..."` (legacy)
///  - Lista JSON de enteros (`[255, 216, ...]`), o su `toString` con corchetes
///
/// La heurística antigua ("si contiene coma es legacy") rompía los Data URI:
/// la coma del encabezado los mandaba al parser de enteros, `int.parse`
/// fallaba y la foto se perdía en silencio. Aquí el formato legacy se detecta
/// de verdad (solo dígitos con signo y comas) y todo lo demás se trata como
/// Base64 normalizado.
Uint8List? decodeApiPhoto(Object? raw) {
  if (raw == null) return null;

  // Bytes directos o lista JSON de enteros.
  if (raw is Uint8List) return raw.isEmpty ? null : raw;
  if (raw is List) {
    if (raw.isEmpty) return null;
    try {
      return Uint8List.fromList([
        for (final e in raw) ((e as num).toInt() + 256) % 256,
      ]);
    } catch (_) {
      return null;
    }
  }

  var s = raw.toString().trim();
  if (s.isEmpty) return null;

  // Data URI → quedarse con el payload posterior a la coma del encabezado.
  if (s.startsWith('data:')) {
    final comma = s.indexOf(',');
    if (comma != -1) s = s.substring(comma + 1).trim();
  }

  // Lista serializada "[1, 2, 3]" → quitar corchetes y tratar como legacy.
  if (s.startsWith('[') && s.endsWith(']')) {
    s = s.substring(1, s.length - 1).trim();
  }

  // Legacy real: SOLO enteros con signo separados por comas.
  if (RegExp(r'^-?\d+(\s*,\s*-?\d+)+$').hasMatch(s)) {
    try {
      return Uint8List.fromList([
        for (final p in s.split(',')) (int.parse(p.trim()) + 256) % 256,
      ]);
    } catch (_) {
      return null;
    }
  }

  // Base64: limpiar whitespace, aceptar variante base64url, completar padding.
  try {
    var normalized = s
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    return base64Decode(normalized);
  } catch (_) {
    AppLogger.warn(
      'PhotoDecoder',
      'Foto en formato no reconocido (${s.length} chars): '
          '"${s.length > 40 ? s.substring(0, 40) : s}…"',
    );
    return null;
  }
}
