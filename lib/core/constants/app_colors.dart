import 'package:flutter/material.dart';

/// Paleta de colores centralizada — COSSMIL App.
/// Azul institucional + verde médico + acentos dorados.
///
/// Incluye tokens semánticos para dark mode con sufijo "Dark" y helpers
/// que resuelven automáticamente según brightness.
class AppColors {
  AppColors._();

  // ── Primary (azul institucional — Design System "Clinical Serenity") ─────
  static const Color primary = Color(0xFF00478D);
  static const Color primaryDark = Color(0xFF003366);
  static const Color primaryMedium = Color(0xFF005EB8);
  static const Color primaryLight = Color(0xFFD6E8F7);

  // ── Accent (verde médico / salud) ─────────────────────────────────────────
  static const Color accent = Color(0xFF059669);
  static const Color accentLight = Color(0xFFD1FAE5);
  static const Color accentDark = Color(0xFF047857);

  // ── Gold (detalles institucionales) ───────────────────────────────────────
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFFEF9C3);
  static const Color razer = Color(0xFF44D62C);

  // ── Surfaces (Design System tonal hierarchy) ──────────────────────────────
  static const Color background = Color(0xFFF7F9FB);          // surface base
  static const Color surfaceContainerLow = Color(0xFFF2F4F6); // low priority
  static const Color surface = Color(0xFFFFFFFF);              // active cards (max lift)
  static const Color surfaceVariant = Color(0xFFE0E3E5);       // recessed/disabled
  static const Color white = Color(0xFFFFFFFF);

  // ── Dark mode surfaces (navy-tinted depth, coherente con azul institucional)
  static const Color darkBackground = Color(0xFF0C1117);
  static const Color darkSurface = Color(0xFF131A23);
  static const Color darkCard = Color(0xFF1A2332);
  static const Color darkElevated = Color(0xFF212C3D);
  static const Color darkBorder = Color(0xFF2A3D56);
  static const Color darkDivider = Color(0xFF1E2B3C);

  // ── Text (on-surface tokens) ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF191C1E);
  static const Color textSecondary = Color(0xFF5A6068);
  static const Color textTertiary = Color(0xFF8A9099);

  // ── Dark text (más cálidos, mejor legibilidad sobre navy) ──────────────
  static const Color darkTextPrimary = Color(0xFFE8ECF2);
  static const Color darkTextSecondary = Color(0xFF9DAABA);
  static const Color darkTextTertiary = Color(0xFF6B7A8D);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Cancel button (rojo semántico elegante) ─────────────────────────────
  static const Color cancelButton = Color(0xFFC62828);
  static const Color cancelButtonDark = Color(0xFFEF5350);
  static const Color cancelBg = Color(0xFFFBE9E7);
  static const Color cancelBgDark = Color(0xFF3D1515);
  static const Color cancelBorder = Color(0xFFE57373);
  static const Color cancelBorderDark = Color(0xFF6D2020);

  // ── Unavailable slot (rojo claro visible) ───────────────────────────────
  static const Color slotUnavailableBg = Color(0xFFFFCDD2);
  static const Color slotUnavailableBgDark = Color(0xFF3D1A1A);
  static const Color slotUnavailableText = Color(0xFFC62828);
  static const Color slotUnavailableTextDark = Color(0xFFEF9A9A);
  static const Color slotUnavailableBorder = Color(0xFFEF9A9A);
  static const Color slotUnavailableBorderDark = Color(0xFF6D2020);

  // ── Borders / Dividers (ghost border — outline-variant at low opacity) ───
  static const Color border = Color(0xFFE0E3E5);
  static const Color divider = Color(0xFFF2F4F6);

  // ── Semantic helpers (resolve by brightness) ──────────────────────────────

  /// Card background that adapts to brightness.
  static Color cardBg(bool isDark) => isDark ? darkCard : white;

  /// Scaffold/page background.
  static Color scaffoldBg(bool isDark) => isDark ? darkBackground : background;

  /// Elevated surface (modals, sheets).
  static Color elevatedBg(bool isDark) => isDark ? darkElevated : white;

  /// Primary text color for current theme.
  static Color textPrimaryC(bool isDark) => isDark ? darkTextPrimary : textPrimary;

  /// Secondary text color for current theme.
  static Color textSecondaryC(bool isDark) => isDark ? darkTextSecondary : textSecondary;

  /// Tertiary text color for current theme.
  static Color textTertiaryC(bool isDark) => isDark ? darkTextTertiary : textTertiary;

  /// Card border for current theme.
  static Color cardBorder(bool isDark) => isDark ? darkBorder : border;

  /// Divider for current theme.
  static Color dividerC(bool isDark) => isDark ? darkDivider : divider;

  /// Accent color for dark mode actions (highlights, active states).
  static Color accentForTheme(bool isDark) => isDark ? const Color(0xFF5BA3E6) : primary;

  /// Subtle accent background.
  static Color accentBg(bool isDark) =>
      isDark ? const Color(0xFF1A2E45) : primaryLight;

  // ── Shadows (tinted with on-surface #191C1E, highly diffused) ──────────────

  static List<BoxShadow> cardShadowFor(bool isDark) => isDark
      ? [
          BoxShadow(
            color: const Color(0xFF040810).withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF1A3A5C).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ]
      : cardShadow;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF191C1E).withValues(alpha: 0.04),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF191C1E).withValues(alpha: 0.03),
          blurRadius: 32,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF191C1E).withValues(alpha: 0.04),
          blurRadius: 40,
          offset: const Offset(0, 12),
        ),
      ];
}
