import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Theme centralizado de la app COSSMIL.
///
/// Configura ThemeData completo para modo claro y oscuro con
/// tipografía, colores, input decoration, cards, appbars, botones, etc.
class AppTheme {
  AppTheme._();

  // ── Font family ─────────────────────────────────────────────────────────
  static const String _fontFamily = '.SF Pro Text';

  // ── Light Theme ─────────────────────────────────────────────────────────
  static ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: _fontFamily,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.textPrimary,
      onError: AppColors.white,
      outline: AppColors.border,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      displayMedium: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      displaySmall: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      headlineSmall: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      titleSmall: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      bodyLarge: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontFamily: _fontFamily,
        decoration: TextDecoration.none,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontFamily: _fontFamily,
        decoration: TextDecoration.none,
      ),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontFamily: _fontFamily),
      labelLarge: TextStyle(color: AppColors.textPrimary, fontFamily: _fontFamily),
      labelMedium: TextStyle(color: AppColors.textSecondary, fontFamily: _fontFamily),
      labelSmall: TextStyle(color: AppColors.textTertiary, fontFamily: _fontFamily),
    ),
    cardTheme: CardThemeData(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 0.5,
      space: 0,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  // ── Dark Theme ──────────────────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.darkBackground,
    fontFamily: _fontFamily,
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF5BA3E6),
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      error: AppColors.error,
      onPrimary: Colors.black,
      onSecondary: AppColors.white,
      onSurface: AppColors.darkTextPrimary,
      onError: AppColors.white,
      outline: AppColors.darkBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        fontFamily: _fontFamily,
      ),
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      displayMedium: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      displaySmall: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      headlineLarge: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      headlineMedium: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      headlineSmall: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      titleMedium: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      titleSmall: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      bodyLarge: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 16,
        fontFamily: _fontFamily,
        decoration: TextDecoration.none,
      ),
      bodyMedium: TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 14,
        fontFamily: _fontFamily,
        decoration: TextDecoration.none,
      ),
      bodySmall: TextStyle(color: AppColors.darkTextSecondary, fontFamily: _fontFamily),
      labelLarge: TextStyle(color: AppColors.darkTextPrimary, fontFamily: _fontFamily),
      labelMedium: TextStyle(color: AppColors.darkTextSecondary, fontFamily: _fontFamily),
      labelSmall: TextStyle(color: AppColors.darkTextTertiary, fontFamily: _fontFamily),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 0.5,
      space: 0,
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
