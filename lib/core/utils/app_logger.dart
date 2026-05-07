import 'package:flutter/foundation.dart';

/// Centralized structured logger.
/// Output only in debug builds — zero overhead in release.
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
      if (err != null) debugPrint('  ↳ $err');
    }
  }

  static void error(String tag, String msg, [Object? err, StackTrace? st]) {
    if (kDebugMode) {
      _log('ERROR', tag, msg);
      if (err != null) debugPrint('  ↳ $err');
      if (st != null) debugPrintStack(stackTrace: st, maxFrames: 8);
    }
  }

  static void _log(String level, String tag, String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.mmm
    debugPrint('[$ts][$level][$tag] $msg');
  }
}
