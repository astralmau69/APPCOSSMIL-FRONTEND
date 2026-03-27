import 'package:flutter/material.dart';

/// Paleta de colores centralizada — COSSMIL App.
/// Azul institucional + verde médico + acentos dorados.
///
/// Incluye tokens semánticos para dark mode con sufijo "Dark" y helpers
/// que resuelven automáticamente según brightness.
class AppColors {
  AppColors._();

  // ── Primary (azul institucional) ──────────────────────────────────────────
  static const Color primary = Color(0xFF0C4A6E);
  static const Color primaryDark = Color(0xFF082F49);
  static const Color primaryMedium = Color(0xFF0369A1);
  static const Color primaryLight = Color(0xFFE0F2FE);

  // ── Accent (verde médico / salud) ─────────────────────────────────────────
  static const Color accent = Color(0xFF059669);
  static const Color accentLight = Color(0xFFD1FAE5);
  static const Color accentDark = Color(0xFF047857);

  // ── Gold (detalles institucionales) ───────────────────────────────────────
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFFEF9C3);
  static const Color razer = Color(0xFF44D62C);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF2F2F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  // ── Dark mode surfaces (elegantes, no negro absoluto) ─────────────────────
  static const Color darkBackground = Color(0xFF0F0F11);
  static const Color darkSurface = Color(0xFF1A1A1E);
  static const Color darkCard = Color(0xFF1E1E22);
  static const Color darkElevated = Color(0xFF252529);
  static const Color darkBorder = Color(0xFF2C2C30);
  static const Color darkDivider = Color(0xFF232327);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // ── Dark text ─────────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF1F1F3);
  static const Color darkTextSecondary = Color(0xFF9A9AA0);
  static const Color darkTextTertiary = Color(0xFF6B6B73);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
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

  // ── Borders / Dividers ────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

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
  static Color accentForTheme(bool isDark) => isDark ? razer : primary;

  /// Subtle accent background.
  static Color accentBg(bool isDark) =>
      isDark ? primary.withValues(alpha: 0.15) : primaryLight;

  // ── Shadows ───────────────────────────────────────────────────────────────

  static List<BoxShadow> cardShadowFor(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
      : cardShadow;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
          blurRadius: 8,
          spreadRadius: -2,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 36,
          spreadRadius: 2,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];
}
