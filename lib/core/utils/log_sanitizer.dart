/// Enmascara datos sensibles (PHI/PII) antes de que lleguen a la consola.
///
/// Defensa en profundidad: aunque [AppLogger] ya solo emite en `kDebugMode`
/// (cero salida en release), cualquier cosa que se registre —una URL, el cuerpo
/// de una excepción, una respuesta del backend— pasa por [scrub] para que un
/// token, una contraseña o un número de carnet (CI) NUNCA aparezcan en claro en
/// logcat/consola.
///
/// Reglas (todas idempotentes): reemplazan el VALOR sensible por `***` y
/// conservan la etiqueta para que el log siga siendo útil al depurar.
class LogSanitizer {
  LogSanitizer._();

  static const _mask = '***';

  /// Claves cuyo valor es sensible en JSON (`"clave":"valor"`). Se comparan con
  /// la comilla de cierre, así `"ci"` no matchea `"ciudad"`.
  static const _sensitiveKeys =
      'access_token|refresh_token|id_token|token|authorization|'
      'password|pass|clave|contrasena|contraseña|pwd|'
      'ci|cedula|cédula|nrodoc|nro_doc|carnet|nroci|nro_ci|documento';

  static final List<(RegExp, String)> _rules = [
    // 1) Bearer <jwt>  → Bearer ***
    (
      RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      '\$1$_mask',
    ),
    // 2) Basic <base64> (Authorization Basic del refresh) → Basic ***
    (RegExp(r'(Basic\s+)[A-Za-z0-9+/]+=*', caseSensitive: false), '\$1$_mask'),
    // 3) JWT suelto (eyJ........) aunque se registre sin el prefijo "Bearer".
    (RegExp(r'eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]+'), _mask),
    // 4) Campo sensible en JSON: "password":"x" / "ci":"123" → "password":"***"
    (
      RegExp('("(?:$_sensitiveKeys)"\\s*:\\s*")[^"]*(")', caseSensitive: false),
      '\$1$_mask\$2',
    ),
    // 5) Campo sensible en form-urlencoded o query: password=xxx → password=***
    (
      RegExp(
        '(?<![A-Za-z0-9_])(?:$_sensitiveKeys)=[^&\\s"]+',
        caseSensitive: false,
      ),
      // conserva el nombre de la clave, enmascara el valor
      '',
    ),
  ];

  /// Devuelve [input] con todo dato sensible reemplazado por `***`.
  /// Si [input] es null retorna cadena vacía.
  static String scrub(Object? input) {
    if (input == null) return '';
    var s = input.toString();
    for (final (re, repl) in _rules) {
      if (repl.isEmpty) {
        // Regla 5: reconstruye "clave=***" preservando el nombre de la clave.
        s = s.replaceAllMapped(re, (m) {
          final hit = m[0]!;
          final eq = hit.indexOf('=');
          return '${hit.substring(0, eq)}=$_mask';
        });
      } else {
        s = s.replaceAllMapped(re, (m) {
          var out = repl;
          for (var g = 1; g <= m.groupCount; g++) {
            out = out.replaceAll('\$$g', m[g] ?? '');
          }
          return out;
        });
      }
    }
    return s;
  }
}
