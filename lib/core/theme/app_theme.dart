import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Theme centralizado de la app COSSMIL.
class AppTheme {
  AppTheme._();

  static const String _fontFamily = '.SF Pro Text';

  static ThemeData light(BuildContext context) {
    final texts = context.texts;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: _fontFamily,
      colorScheme: const ColorScheme.light(
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
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: texts.titleLarge.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: texts.displayLarge.copyWith(color: AppColors.textPrimary),
        headlineLarge: texts.headlineLarge.copyWith(color: AppColors.textPrimary),
        headlineMedium: texts.headlineMedium.copyWith(color: AppColors.textPrimary),
        titleLarge: texts.titleLarge.copyWith(color: AppColors.textPrimary),
        titleMedium: texts.titleMedium.copyWith(color: AppColors.textPrimary),
        bodyLarge: texts.bodyLarge.copyWith(color: AppColors.textPrimary),
        bodyMedium: texts.bodyMedium.copyWith(color: AppColors.textPrimary),
        bodySmall: texts.bodySmall.copyWith(color: AppColors.textSecondary),
        labelLarge: texts.labelLarge.copyWith(color: AppColors.textPrimary),
        labelSmall: texts.labelSmall.copyWith(color: AppColors.textTertiary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 0,
      ),
    );
  }

  static ThemeData dark(BuildContext context) {
    final texts = context.texts;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: _fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5BA3E6),
        secondary: AppColors.accent,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: AppColors.white,
        onSurface: AppColors.darkTextPrimary,
        onError: AppColors.white,
        outline: AppColors.darkBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: texts.titleLarge.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: texts.displayLarge.copyWith(color: AppColors.darkTextPrimary),
        headlineLarge: texts.headlineLarge.copyWith(color: AppColors.darkTextPrimary),
        headlineMedium: texts.headlineMedium.copyWith(color: AppColors.darkTextPrimary),
        titleLarge: texts.titleLarge.copyWith(color: AppColors.darkTextPrimary),
        titleMedium: texts.titleMedium.copyWith(color: AppColors.darkTextPrimary),
        bodyLarge: texts.bodyLarge.copyWith(color: AppColors.darkTextPrimary),
        bodyMedium: texts.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
        bodySmall: texts.bodySmall.copyWith(color: AppColors.darkTextSecondary),
        labelLarge: texts.labelLarge.copyWith(color: AppColors.darkTextPrimary),
        labelSmall: texts.labelSmall.copyWith(color: AppColors.darkTextTertiary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 0.5,
        space: 0,
      ),
    );
  }

  // ── Radius constants ──────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusFull = 100;
}
