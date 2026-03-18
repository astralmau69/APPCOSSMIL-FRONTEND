import 'package:flutter/material.dart';

/// Paleta de colores centralizada — COSSMIL App.
/// Azul institucional + verde médico + acentos dorados.
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

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color white = Color(0xFFFFFFFF);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Borders / Dividers ────────────────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
