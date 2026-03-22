import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Theme centralizado de la app COSSMIL.
class AppTheme {
  AppTheme._();

  static ThemeData theme = ThemeData(
    primaryColor: AppColors.primary,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: '.SF Pro Text',
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData darkTheme = ThemeData(
    primaryColor: AppColors.primary,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF111111), // Dark mode background
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1C1C1E),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: '.SF Pro Text',
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
      bodyMedium: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontFamily: '.SF Pro Text',
        decoration: TextDecoration.none,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  // ── Spacing constants ─────────────────────────────────────────────────────
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacing2xl = 48;

  // ── Radius ────────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 100;

  // ── Responsive helpers ────────────────────────────────────────────────────

  /// Horizontal padding basado en ancho de pantalla.
  static double horizontalPadding(double screenWidth) {
    if (screenWidth >= 600) return 32;
    if (screenWidth >= 400) return 20;
    return 16;
  }

  /// Tamaño de logo responsive.
  static double logoSize(double screenWidth) {
    if (screenWidth >= 600) return 140;
    if (screenWidth >= 400) return 120;
    return 100;
  }
}
