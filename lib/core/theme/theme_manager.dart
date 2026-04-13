import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// App-wide theme notifier. Supports manual switching without provider.
/// Persists the chosen mode so it survives app restarts (REPORTE 001).
class ThemeManager {
  ThemeManager._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'app_theme_mode';

  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.system);

  /// Initialise from persisted preference. Call once in main() / splash.
  static Future<void> init() async {
    try {
      final stored = await _storage.read(key: _key);
      if (stored != null) {
        themeNotifier.value = _fromString(stored);
      }
    } catch (_) {
      // Keep default (system) if storage fails.
    }
  }

  static Future<void> toggleTheme() async {
    final next = themeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    try {
      await _storage.write(key: _key, value: _toString(mode));
    } catch (_) {}
  }

  static String _toString(ThemeMode m) => switch (m) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        _ => 'system',
      };

  static ThemeMode _fromString(String s) => switch (s) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
}
