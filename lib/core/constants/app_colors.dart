import 'package:flutter/cupertino.dart';

/// Colores centralizados del tema COSSMIL.
class AppColors {
  // ── Branding ───────────────────────────────────────────────────────────
  static const Color olive = Color(0xFF6B6830);
  static const Color oliveLight = Color(0xFF8A8548);
  static const Color olivePale = Color(0xFFE8E6D0);

  // ── Backgrounds ────────────────────────────────────────────────────────
  static const Color bgGrey = Color(0xFFF2F2F7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────
  static const Color darkText = Color(0xFF1C1C1E);
  static const Color subtleGrey = Color(0xFF8E8E93);
  static const Color labelGrey = Color(0xFF636366);

  // ── Accents ────────────────────────────────────────────────────────────
  static const Color errorRed = Color(0xFFD70015);
  static const Color successGreen = Color(0xFF34C759);
  static const Color authorizedGreen = Color(0xFF4A7C59);
  static const Color infoBlue = Color(0xFF5B7FC7);
  static const Color infoBlueBg = Color(0xFFF0F4FF);
  static const Color infoBlueBorder = Color(0xFFD0DAFA);
  static const Color bloodRed = Color(0xFFD32F2F);

  // ── Borders / Dividers ─────────────────────────────────────────────────
  static const Color cardBorder = Color(0xFFE5E5EA);
  static const Color divider = Color(0xFFE0E0E0);

  // ── Shadows helper ─────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
}
