import 'package:flutter/material.dart';

/// App-wide theme notifier. Supports manual switching without provider.
class ThemeManager {
  static final ValueNotifier<ThemeMode> themeNotifier = 
      ValueNotifier(ThemeMode.system);

  static void toggleTheme() {
    if (themeNotifier.value == ThemeMode.light || themeNotifier.value == ThemeMode.system) {
      themeNotifier.value = ThemeMode.dark;
    } else {
      themeNotifier.value = ThemeMode.light;
    }
  }

  static void setThemeMode(ThemeMode mode) {
    themeNotifier.value = mode;
  }
}
