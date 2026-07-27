import 'package:flutter/foundation.dart';

import 'log_sanitizer.dart';

/// Centralized structured logger.
/// Output only in debug builds — zero overhead in release.
///
/// Todo lo que se imprime pasa por [LogSanitizer.scrub], de modo que tokens,
/// contraseñas y números de carnet (CI) jamás salen en claro (defensa en
/// profundidad, incluso para el objeto de error que se pasa a [warn]/[error]).
class AppLogger {
  AppLogger._();

  static void debug(String tag, String msg) {
    if (kDebugMode) _log('DEBUG', tag, msg);
  }

  static void info(String tag, String msg) {
    if (kDebugMode) _log('INFO ', tag, msg);
  }

  static void warn(String tag, String msg, [Object? err]) {
    if (kDebugMode) {
      _log('WARN ', tag, msg);
      if (err != null) debugPrint('  ↳ ${LogSanitizer.scrub(err)}');
    }
  }

  static void error(String tag, String msg, [Object? err, StackTrace? st]) {
    if (kDebugMode) {
      _log('ERROR', tag, msg);
      if (err != null) debugPrint('  ↳ ${LogSanitizer.scrub(err)}');
      if (st != null) debugPrintStack(stackTrace: st, maxFrames: 8);
    }
  }

  static void _log(String level, String tag, String msg) {
    final ts = DateTime.now().toIso8601String().substring(
      11,
      23,
    ); // HH:mm:ss.mmm
    debugPrint('[$ts][$level][$tag] ${LogSanitizer.scrub(msg)}');
  }
}
