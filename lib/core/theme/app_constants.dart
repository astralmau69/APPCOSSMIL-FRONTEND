import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Sistema mejorado de espaciado y constantes visuales.
/// Eliminados los tamaños rígidos, reemplazados con un sistema token-based.
class AppSpacing {
  AppSpacing._();

  // Token spacing - basado en escala 4px
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Radios - consistentes con Material 3
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusMax = 28;
  static const double radiusFull = 100;

  // Icon sizes standardizados
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 48;

  // Avatar sizes
  static const double avatarXs = 32;
  static const double avatarSm = 40;
  static const double avatarMd = 48;
  static const double avatarLg = 56;
  static const double avatarXl = 64;

  // Gutter/Gap spacing
  static const double gutterXs = 4;
  static const double gutterSm = 8;
  static const double gutterMd = 12;
  static const double gutterLg = 16;
  static const double gutterXl = 24;
}

/// Sistema de tipografía unificado y limpio.
class AppTypography {
  AppTypography._();

  // Display - Titles ultra-grandes (splash, onboarding)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // Headline - Section titles grandes
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  // Title - Card titles, strong emphasis
  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  // Body - Contenido principal
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    height: 1.6,
    color: AppColors.textSecondary,
  );

  // Label - Badges, buttons, annotations
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.3,
    color: AppColors.textTertiary,
  );

  // Caption - Smallest text
  static const TextStyle caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.2,
    color: AppColors.textTertiary,
  );
}

/// Sistema de sombras unificado y optimizado.
class AppShadows {
  AppShadows._();

  /// Sombra ultra-fina para borders/dividers
  static List<BoxShadow> get hairline => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.01),
      blurRadius: 0.5,
      offset: const Offset(0, 0.5),
    ),
  ];

  /// Sombra suave para elementos elevados minimamente
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Sombra estándar para cards
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Sombra media para elementos más prominentes
  static List<BoxShadow> get medium => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  /// Sombra elevada para modales/popovers
  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.02),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// Sombra muy elevada para sheets/modales prominentes
  static List<BoxShadow> get veryElevated => [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: 0.01),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Durations estándar para animaciones
class AppDurations {
  AppDurations._();

  // Animaciones rápidas (feedback inmediato)
  static const Duration ultra = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);

  /// Transiciones cortas de interfaz (aparecer/desaparecer, cambios de estado
  /// de una tarjeta). Cubre el salto entre [fast] y [normal]: el código venía
  /// usando 180/200/220/250/260 ms en una decena de sitios porque no existía
  /// un peldaño intermedio, y esa dispersión es justo lo que hacía que nada se
  /// sintiera parte del mismo sistema.
  static const Duration quick = Duration(milliseconds: 200);

  // Animaciones normales (transiciones suaves)
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Animaciones lentas (disclosure, modales)
  static const Duration verySlow = Duration(milliseconds: 700);
  static const Duration extra = Duration(milliseconds: 1000);
}

/// Curves estándar para animaciones
class AppCurves {
  AppCurves._();

  static const Curve instant = Curves.linear;
  static const Curve snappy = Curves.easeOutCubic;
  static const Curve smooth = Curves.easeOut;
  static const Curve smoothIn = Curves.easeIn;
  static const Curve bounce = Curves.easeOutBack;
  static const Curve elasticity = Curves.elasticOut;
}
