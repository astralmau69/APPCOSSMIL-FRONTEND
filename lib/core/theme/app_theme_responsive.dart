import 'package:flutter/material.dart';

/// Sistema de tema responsive completo para COSSMIL.
/// Soporta múltiples breakpoints: phones pequeños, phones medianos, phones grandes, tablets, landscape.
///
/// Uso:
/// ```dart
/// final sizes = ResponsiveTheme.of(context);
/// Text('Hola', style: TextStyle(fontSize: sizes.typography.titleLarge))
/// ```
class ResponsiveTheme {
  // Breakpoints para diferentes dispositivos
  static const double _phoneMd = 375; // iPhone base
  static const double _phoneLg = 428; // iPhone Pro, large Android
  static const double _tabletSm =
      600; // iPad mini horizontal / Android tablets start
  static const double _tabletMd = 768; // iPad normal
  static const double _tabletLg = 1024; // iPad Pro

  final double screenWidth;
  final double screenHeight;
  final bool isPhone;
  final bool isTabletSm;
  final bool isTabletMd;
  final bool isTabletLg;
  final bool isLandscape;
  final DeviceCategory deviceCategory;

  ResponsiveTheme._({
    required this.screenWidth,
    required this.screenHeight,
    required this.isPhone,
    required this.isTabletSm,
    required this.isTabletMd,
    required this.isTabletLg,
    required this.isLandscape,
    required this.deviceCategory,
  });

  factory ResponsiveTheme.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final isLandscape = width > height;

    late DeviceCategory category;
    bool isPhoneVal = true;
    bool isTabletSmVal = false;
    bool isTabletMdVal = false;
    bool isTabletLgVal = false;

    if (width >= _tabletLg) {
      category = DeviceCategory.tabletLarge;
      isPhoneVal = false;
      isTabletLgVal = true;
    } else if (width >= _tabletMd) {
      category = DeviceCategory.tabletMedium;
      isPhoneVal = false;
      isTabletMdVal = true;
    } else if (width >= _tabletSm) {
      category = DeviceCategory.tabletSmall;
      isPhoneVal = false;
      isTabletSmVal = true;
    } else if (width >= _phoneLg) {
      category = DeviceCategory.phoneLarge;
    } else if (width >= _phoneMd) {
      category = DeviceCategory.phoneMedium;
    } else {
      category = DeviceCategory.phoneSmall;
    }

    return ResponsiveTheme._(
      screenWidth: width,
      screenHeight: height,
      isPhone: isPhoneVal,
      isTabletSm: isTabletSmVal,
      isTabletMd: isTabletMdVal,
      isTabletLg: isTabletLgVal,
      isLandscape: isLandscape,
      deviceCategory: category,
    );
  }

  // ── TYPOGRAPHY RESPONSIVE ──────────────────────────────────────────────────

  late final typography = _Typography(this);

  // ── SPACING RESPONSIVE ─────────────────────────────────────────────────────

  double get paddingXs => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 4,
    DeviceCategory.phoneMedium => 4,
    DeviceCategory.phoneLarge => 4,
    DeviceCategory.tabletSmall => 6,
    DeviceCategory.tabletMedium => 8,
    DeviceCategory.tabletLarge => 8,
  };

  double get paddingSm => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 6,
    DeviceCategory.phoneMedium => 8,
    DeviceCategory.phoneLarge => 8,
    DeviceCategory.tabletSmall => 10,
    DeviceCategory.tabletMedium => 12,
    DeviceCategory.tabletLarge => 12,
  };

  double get paddingMd => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 12,
    DeviceCategory.phoneMedium => 14,
    DeviceCategory.phoneLarge => 16,
    DeviceCategory.tabletSmall => 18,
    DeviceCategory.tabletMedium => 20,
    DeviceCategory.tabletLarge => 24,
  };

  double get paddingLg => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 16,
    DeviceCategory.phoneMedium => 18,
    DeviceCategory.phoneLarge => 20,
    DeviceCategory.tabletSmall => 24,
    DeviceCategory.tabletMedium => 28,
    DeviceCategory.tabletLarge => 32,
  };

  double get paddingXl => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 20,
    DeviceCategory.phoneMedium => 24,
    DeviceCategory.phoneLarge => 28,
    DeviceCategory.tabletSmall => 32,
    DeviceCategory.tabletMedium => 36,
    DeviceCategory.tabletLarge => 40,
  };

  /// Padding horizontal estándar para pantalla.
  double get horizontalPadding => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 12,
    DeviceCategory.phoneMedium => 14,
    DeviceCategory.phoneLarge => 16,
    DeviceCategory.tabletSmall => 20,
    DeviceCategory.tabletMedium => 24,
    DeviceCategory.tabletLarge => 32,
  };

  /// Ancho máximo de contenido para tablets.
  double get maxContentWidth => switch (deviceCategory) {
    DeviceCategory.phoneSmall => double.infinity,
    DeviceCategory.phoneMedium => double.infinity,
    DeviceCategory.phoneLarge => double.infinity,
    DeviceCategory.tabletSmall => 640,
    DeviceCategory.tabletMedium => 800,
    DeviceCategory.tabletLarge => 1000,
  };

  // ── RADII RESPONSIVE ───────────────────────────────────────────────────────

  double get radiusSm => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 6,
    DeviceCategory.phoneMedium => 8,
    DeviceCategory.phoneLarge => 8,
    DeviceCategory.tabletSmall => 8,
    DeviceCategory.tabletMedium => 10,
    DeviceCategory.tabletLarge => 12,
  };

  double get radiusMd => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 8,
    DeviceCategory.phoneMedium => 10,
    DeviceCategory.phoneLarge => 12,
    DeviceCategory.tabletSmall => 12,
    DeviceCategory.tabletMedium => 14,
    DeviceCategory.tabletLarge => 16,
  };

  double get radiusLg => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 10,
    DeviceCategory.phoneMedium => 12,
    DeviceCategory.phoneLarge => 14,
    DeviceCategory.tabletSmall => 16,
    DeviceCategory.tabletMedium => 18,
    DeviceCategory.tabletLarge => 20,
  };

  double get radiusXl => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 12,
    DeviceCategory.phoneMedium => 14,
    DeviceCategory.phoneLarge => 16,
    DeviceCategory.tabletSmall => 18,
    DeviceCategory.tabletMedium => 20,
    DeviceCategory.tabletLarge => 24,
  };

  double get radiusFull => 100;

  // ── ICON SIZES RESPONSIVE ──────────────────────────────────────────────────

  double get iconSm => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 18,
    DeviceCategory.phoneMedium => 20,
    DeviceCategory.phoneLarge => 20,
    DeviceCategory.tabletSmall => 22,
    DeviceCategory.tabletMedium => 24,
    DeviceCategory.tabletLarge => 26,
  };

  double get iconMd => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 22,
    DeviceCategory.phoneMedium => 24,
    DeviceCategory.phoneLarge => 26,
    DeviceCategory.tabletSmall => 28,
    DeviceCategory.tabletMedium => 30,
    DeviceCategory.tabletLarge => 32,
  };

  double get iconLg => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 30,
    DeviceCategory.phoneMedium => 32,
    DeviceCategory.phoneLarge => 36,
    DeviceCategory.tabletSmall => 40,
    DeviceCategory.tabletMedium => 44,
    DeviceCategory.tabletLarge => 48,
  };

  // ── AVATAR/IMAGE SIZES RESPONSIVE ──────────────────────────────────────────

  double get avatarRadiusSm => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 24,
    DeviceCategory.phoneMedium => 28,
    DeviceCategory.phoneLarge => 32,
    DeviceCategory.tabletSmall => 36,
    DeviceCategory.tabletMedium => 40,
    DeviceCategory.tabletLarge => 44,
  };

  double get avatarRadius => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 32,
    DeviceCategory.phoneMedium => 40,
    DeviceCategory.phoneLarge => 44,
    DeviceCategory.tabletSmall => 48,
    DeviceCategory.tabletMedium => 52,
    DeviceCategory.tabletLarge => 56,
  };

  double get avatarRadiusLg => switch (deviceCategory) {
    DeviceCategory.phoneSmall => 40,
    DeviceCategory.phoneMedium => 48,
    DeviceCategory.phoneLarge => 56,
    DeviceCategory.tabletSmall => 60,
    DeviceCategory.tabletMedium => 68,
    DeviceCategory.tabletLarge => 76,
  };

  // ── SHADOWS RESPONSIVE ─────────────────────────────────────────────────────

  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: isPhone ? 12 : 16,
      offset: Offset(0, isPhone ? 2 : 4),
    ),
  ];

  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      blurRadius: isPhone ? 8 : 12,
      offset: const Offset(0, 2),
    ),
  ];

  List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      blurRadius: isPhone ? 16 : 24,
      offset: Offset(0, isPhone ? 4 : 8),
    ),
  ];
}

/// Categoría de dispositivo
enum DeviceCategory {
  phoneSmall, // < 375dp
  phoneMedium, // 375-428dp
  phoneLarge, // 428-600dp
  tabletSmall, // 600-768dp
  tabletMedium, // 768-1024dp
  tabletLarge, // >= 1024dp
}

/// Sistema de tipografía responsive.
class _Typography {
  final ResponsiveTheme theme;

  _Typography(this.theme);

  // Display - Títulos enormes (splash, headers principales)
  TextStyle get displayLarge => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 32,
      DeviceCategory.phoneMedium => 36,
      DeviceCategory.phoneLarge => 40,
      DeviceCategory.tabletSmall => 44,
      DeviceCategory.tabletMedium => 48,
      DeviceCategory.tabletLarge => 56,
    },
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    height: 1.2,
  );

  // Headline - Títulos grandes (screens principales)
  TextStyle get headlineLarge => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 24,
      DeviceCategory.phoneMedium => 26,
      DeviceCategory.phoneLarge => 28,
      DeviceCategory.tabletSmall => 32,
      DeviceCategory.tabletMedium => 36,
      DeviceCategory.tabletLarge => 40,
    },
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.3,
  );

  // Headline Medium
  TextStyle get headlineMedium => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 20,
      DeviceCategory.phoneMedium => 22,
      DeviceCategory.phoneLarge => 24,
      DeviceCategory.tabletSmall => 28,
      DeviceCategory.tabletMedium => 32,
      DeviceCategory.tabletLarge => 36,
    },
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.35,
  );

  // Title Large - Cards, secondary titles
  TextStyle get titleLarge => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 18,
      DeviceCategory.phoneMedium => 20,
      DeviceCategory.phoneLarge => 22,
      DeviceCategory.tabletSmall => 24,
      DeviceCategory.tabletMedium => 26,
      DeviceCategory.tabletLarge => 28,
    },
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.4,
  );

  // Title Medium - Subtítulos, labels
  TextStyle get titleMedium => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 16,
      DeviceCategory.phoneMedium => 17,
      DeviceCategory.phoneLarge => 18,
      DeviceCategory.tabletSmall => 20,
      DeviceCategory.tabletMedium => 22,
      DeviceCategory.tabletLarge => 24,
    },
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.5,
  );

  // Body Large - Cuerpo principal
  TextStyle get bodyLarge => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 14,
      DeviceCategory.phoneMedium => 15,
      DeviceCategory.phoneLarge => 16,
      DeviceCategory.tabletSmall => 17,
      DeviceCategory.tabletMedium => 18,
      DeviceCategory.tabletLarge => 19,
    },
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.6,
  );

  // Body Medium - Descripción, metadata
  TextStyle get bodyMedium => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 13,
      DeviceCategory.phoneMedium => 14,
      DeviceCategory.phoneLarge => 15,
      DeviceCategory.tabletSmall => 16,
      DeviceCategory.tabletMedium => 17,
      DeviceCategory.tabletLarge => 18,
    },
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.6,
  );

  // Body Small - Labels, hints
  TextStyle get bodySmall => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 12,
      DeviceCategory.phoneMedium => 13,
      DeviceCategory.phoneLarge => 14,
      DeviceCategory.tabletSmall => 15,
      DeviceCategory.tabletMedium => 16,
      DeviceCategory.tabletLarge => 17,
    },
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );

  // Label Large - Botones, badges
  TextStyle get labelLarge => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 13,
      DeviceCategory.phoneMedium => 14,
      DeviceCategory.phoneLarge => 15,
      DeviceCategory.tabletSmall => 16,
      DeviceCategory.tabletMedium => 17,
      DeviceCategory.tabletLarge => 18,
    },
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.4,
  );

  // Label Small
  TextStyle get labelSmall => TextStyle(
    fontSize: switch (theme.deviceCategory) {
      DeviceCategory.phoneSmall => 11,
      DeviceCategory.phoneMedium => 12,
      DeviceCategory.phoneLarge => 13,
      DeviceCategory.tabletSmall => 14,
      DeviceCategory.tabletMedium => 15,
      DeviceCategory.tabletLarge => 16,
    },
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.3,
  );
}
