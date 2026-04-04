import 'package:flutter/material.dart';

/// Helpers y extensiones para layouts responsive sin código duplicado.
extension MediaQueryExtension on BuildContext {
  double get width => MediaQuery.of(this).size.width;
  double get height => MediaQuery.of(this).size.height;

  bool get isSmallPhone => width < 375;
  bool get isMediumPhone => width >= 375 && width < 428;
  bool get isLargePhone => width >= 428 && width < 600;
  bool get isTablet => width >= 600;
  bool get isLargeTablet => width >= 1024;
  bool get isLandscape => width > height;
  bool get isPortrait => height > width;
}

/// Acceso rápido al sistema responsive unificado.
/// Uso: `final r = context.r;`  luego  `r.paddingH`, `r.fontSize.bodyLarge`, etc.
extension ResponsiveExtension on BuildContext {
  AppResponsive get r => AppResponsive.of(this);
}

/// Extensión para acceder a tipografía responsiva unificada desde el context.
/// Uso: context.texts.bodyLarge
extension TypographyExtension on BuildContext {
  ResponsiveTypography get texts => ResponsiveTypography.of(this);
}

/// Sistema responsive unificado — UN solo punto de acceso para toda la app.
/// Resuelve spacing, tipografía, radii, icon sizes y constraints por breakpoint.
class AppResponsive {
  final double screenWidth;
  final double screenHeight;
  final DeviceType deviceType;
  final Orientation orientation;

  const AppResponsive._({
    required this.screenWidth,
    required this.screenHeight,
    required this.deviceType,
    required this.orientation,
  });

  factory AppResponsive.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    return AppResponsive._(
      screenWidth: size.width,
      screenHeight: size.height,
      deviceType: _getDeviceType(size.width),
      orientation: orientation,
    );
  }

  static DeviceType _getDeviceType(double width) {
    if (width >= 1024) return DeviceType.tabletLarge;
    if (width >= 768) return DeviceType.tabletMedium;
    if (width >= 600) return DeviceType.tabletSmall;
    if (width >= 428) return DeviceType.phoneLarge;
    if (width >= 375) return DeviceType.phoneMedium;
    return DeviceType.phoneSmall;
  }

  bool get isPhone => deviceType.index < 3;
  bool get isTablet => deviceType.index >= 3;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isSmallPhone => deviceType == DeviceType.phoneSmall;
  bool get isMediumPhone => deviceType == DeviceType.phoneMedium;
  bool get isLargePhone => deviceType == DeviceType.phoneLarge;

  // ── Selector helper ────────────────────────────────────────────────────────
  T _select<T>({
    required T phoneSmall,
    required T phoneMedium,
    required T phoneLarge,
    required T tablet,
  }) {
    return switch (deviceType) {
      DeviceType.phoneSmall => phoneSmall,
      DeviceType.phoneMedium => phoneMedium,
      DeviceType.phoneLarge => phoneLarge,
      DeviceType.tabletSmall ||
      DeviceType.tabletMedium ||
      DeviceType.tabletLarge => tablet,
    };
  }

  // ── HORIZONTAL PADDING (pantalla) ──────────────────────────────────────────
  double get paddingH => _select(
    phoneSmall: 12,
    phoneMedium: 16,
    phoneLarge: 20,
    tablet: 24,
  );

  // ── VERTICAL SPACING ──────────────────────────────────────────────────────
  double get spaceXs => _select(phoneSmall: 4, phoneMedium: 4, phoneLarge: 4, tablet: 6);
  double get spaceSm => _select(phoneSmall: 6, phoneMedium: 8, phoneLarge: 8, tablet: 10);
  double get spaceMd => _select(phoneSmall: 12, phoneMedium: 14, phoneLarge: 16, tablet: 20);
  double get spaceLg => _select(phoneSmall: 16, phoneMedium: 20, phoneLarge: 24, tablet: 28);
  double get spaceXl => _select(phoneSmall: 20, phoneMedium: 24, phoneLarge: 28, tablet: 36);
  double get spaceXxl => _select(phoneSmall: 28, phoneMedium: 32, phoneLarge: 40, tablet: 48);

  // ── CARD PADDING ──────────────────────────────────────────────────────────
  double get cardPadding => _select(phoneSmall: 12, phoneMedium: 14, phoneLarge: 16, tablet: 20);

  // ── MAX CONTENT WIDTH (limita el ancho en tablets) ─────────────────────────
  double get maxContentWidth => _select(
    phoneSmall: double.infinity,
    phoneMedium: double.infinity,
    phoneLarge: double.infinity,
    tablet: 680,
  );

  // ── RADII ─────────────────────────────────────────────────────────────────
  double get radiusSm => _select(phoneSmall: 6, phoneMedium: 8, phoneLarge: 8, tablet: 10);
  double get radiusMd => _select(phoneSmall: 10, phoneMedium: 12, phoneLarge: 12, tablet: 14);
  double get radiusLg => _select(phoneSmall: 12, phoneMedium: 16, phoneLarge: 16, tablet: 18);
  double get radiusXl => _select(phoneSmall: 14, phoneMedium: 18, phoneLarge: 20, tablet: 22);

  // ── ICON SIZES ────────────────────────────────────────────────────────────
  double get iconSm => _select(phoneSmall: 18, phoneMedium: 20, phoneLarge: 20, tablet: 24);
  double get iconMd => _select(phoneSmall: 22, phoneMedium: 24, phoneLarge: 26, tablet: 28);
  double get iconLg => _select(phoneSmall: 28, phoneMedium: 32, phoneLarge: 36, tablet: 40);

  // ── AVATAR SIZES ──────────────────────────────────────────────────────────
  double get avatarSm => _select(phoneSmall: 32, phoneMedium: 36, phoneLarge: 40, tablet: 44);
  double get avatarMd => _select(phoneSmall: 40, phoneMedium: 48, phoneLarge: 52, tablet: 56);
  double get avatarLg => _select(phoneSmall: 52, phoneMedium: 60, phoneLarge: 68, tablet: 76);

  // ── BUTTON HEIGHT ─────────────────────────────────────────────────────────
  double get buttonHeight => _select(phoneSmall: 48, phoneMedium: 52, phoneLarge: 56, tablet: 56);

  // ── BOTTOM NAV PADDING (espacio para el floating nav bar) ─────────────────
  double get navBarBottomSpace => _select(
    phoneSmall: 100,
    phoneMedium: 110,
    phoneLarge: 120,
    tablet: 120,
  );

  // ── PIN KEY SIZE ──────────────────────────────────────────────────────────
  double get pinKeySize => _select(phoneSmall: 64, phoneMedium: 72, phoneLarge: 82, tablet: 82);
  double get pinKeypadPadding => _select(phoneSmall: 24, phoneMedium: 36, phoneLarge: 48, tablet: 60);

  // ── PROFILE AVATAR (large for perfil screen) ──────────────────────────────
  double get profileAvatarSize => _select(phoneSmall: 80, phoneMedium: 96, phoneLarge: 110, tablet: 120);

  // ── BOOKING STEPPER ────────────────────────────────────────────────────────
  double get stepperLogoSize => _select(phoneSmall: 32, phoneMedium: 40, phoneLarge: 48, tablet: 56);
  double get stepperCircleSize => _select(phoneSmall: 24, phoneMedium: 28, phoneLarge: 30, tablet: 34);
  double get stepperCircleSizeCurrent => _select(phoneSmall: 28, phoneMedium: 32, phoneLarge: 36, tablet: 40);

  // ── HOSPITAL/DOCTOR ICON ──────────────────────────────────────────────────
  double get listAvatarSize => _select(phoneSmall: 44, phoneMedium: 50, phoneLarge: 56, tablet: 60);

  // ── TIME CHIP ─────────────────────────────────────────────────────────────
  double get timeChipWidth => _select(phoneSmall: 86, phoneMedium: 96, phoneLarge: 108, tablet: 116);

  // ── GRID ──────────────────────────────────────────────────────────────────
  int get gridColumns => isTablet ? (isLandscape ? 3 : 2) : 2;
  double get gridSpacing => _select(phoneSmall: 8, phoneMedium: 10, phoneLarge: 12, tablet: 16);

  // ── EDGE INSETS HELPERS ───────────────────────────────────────────────────
  EdgeInsets get screenPadding => EdgeInsets.symmetric(horizontal: paddingH);
  EdgeInsets get cardInsets => EdgeInsets.all(cardPadding);
}

/// Helper para construir layouts responsivos de forma simple y limpia.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, ResponsiveData) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final data = ResponsiveData.of(context);
    return builder(context, data);
  }
}

/// Data sobre el tamaño y categoría del dispositivo actual (legacy, usar AppResponsive).
class ResponsiveData {
  final double screenWidth;
  final double screenHeight;
  final DeviceType deviceType;
  final Orientation orientation;

  const ResponsiveData({
    required this.screenWidth,
    required this.screenHeight,
    required this.deviceType,
    required this.orientation,
  });

  factory ResponsiveData.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    final deviceType = _getDeviceType(size.width);
    return ResponsiveData(
      screenWidth: size.width,
      screenHeight: size.height,
      deviceType: deviceType,
      orientation: orientation,
    );
  }

  static DeviceType _getDeviceType(double width) {
    if (width >= 1024) return DeviceType.tabletLarge;
    if (width >= 768) return DeviceType.tabletMedium;
    if (width >= 600) return DeviceType.tabletSmall;
    if (width >= 428) return DeviceType.phoneLarge;
    if (width >= 375) return DeviceType.phoneMedium;
    return DeviceType.phoneSmall;
  }

  bool get isPhone => deviceType.index < 3;
  bool get isTablet => deviceType.index >= 3;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isSmallPhone => deviceType == DeviceType.phoneSmall;
  bool get isMediumPhone => deviceType == DeviceType.phoneMedium;
  bool get isLargePhone => deviceType == DeviceType.phoneLarge;
}

/// Sistema de tipografía responsiva que unifica los tamaños en toda la app.
class ResponsiveTypography {
  final ResponsiveData responsive;

  ResponsiveTypography(this.responsive);

  factory ResponsiveTypography.of(BuildContext context) {
    return ResponsiveTypography(ResponsiveData.of(context));
  }

  double _getResponsiveSize({
    required double small,
    required double medium,
    required double large,
    required double tablet,
  }) {
    return switch (responsive.deviceType) {
      DeviceType.phoneSmall => small,
      DeviceType.phoneMedium => medium,
      DeviceType.phoneLarge => large,
      DeviceType.tabletSmall || DeviceType.tabletMedium || DeviceType.tabletLarge => tablet,
    };
  }

  TextStyle _base(double size, {FontWeight weight = FontWeight.w500, double? letterSpacing, double? height}) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      fontFamily: '.SF Pro Text',
    );
  }

  // DISPLAY - Títulos ultra-grandes
  TextStyle get displayLarge => _base(_getResponsiveSize(small: 28, medium: 32, large: 36, tablet: 44), weight: FontWeight.w900, letterSpacing: -1.0);

  // HEADLINE - Títulos de secciones
  TextStyle get headlineLarge => _base(_getResponsiveSize(small: 22, medium: 24, large: 28, tablet: 32), weight: FontWeight.w800, letterSpacing: -0.5);
  TextStyle get headlineMedium => _base(_getResponsiveSize(small: 18, medium: 20, large: 22, tablet: 26), weight: FontWeight.w700);

  // TITLE - Títulos de tarjetas / subtítulos
  TextStyle get titleLarge => _base(_getResponsiveSize(small: 16, medium: 17, large: 18, tablet: 22), weight: FontWeight.w700);
  TextStyle get titleMedium => _base(_getResponsiveSize(small: 14, medium: 15, large: 16, tablet: 20), weight: FontWeight.w600);

  // BODY - Contenido principal
  TextStyle get bodyLarge => _base(_getResponsiveSize(small: 14, medium: 15, large: 16, tablet: 18), weight: FontWeight.w500, height: 1.5);
  TextStyle get bodyMedium => _base(_getResponsiveSize(small: 13, medium: 14, large: 15, tablet: 17), weight: FontWeight.w500, height: 1.4);
  TextStyle get bodySmall => _base(_getResponsiveSize(small: 11, medium: 12, large: 13, tablet: 15), weight: FontWeight.w400, height: 1.3);

  // LABEL - Botones y pequeñas anotaciones
  TextStyle get labelLarge => _base(_getResponsiveSize(small: 13, medium: 14, large: 15, tablet: 17), weight: FontWeight.w700, letterSpacing: 0.5);
  TextStyle get labelSmall => _base(_getResponsiveSize(small: 10, medium: 11, large: 12, tablet: 14), weight: FontWeight.w600, letterSpacing: 0.5);
}

enum DeviceType {
  phoneSmall,      // < 375
  phoneMedium,     // 375-428
  phoneLarge,      // 428-600
  tabletSmall,     // 600-768
  tabletMedium,    // 768-1024
  tabletLarge,     // >= 1024
}

/// Helper para contenedores responsive con ancho máximo en tablets.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final effectiveMaxWidth = maxWidth ?? r.maxContentWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

/// Wrapper que aplica max-width centrado + padding horizontal responsive.
/// Ideal para envolver el contenido de un sliver o un ListView.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final bool addHorizontalPadding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth,
    this.addHorizontalPadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final effectiveMaxWidth = maxWidth ?? r.maxContentWidth;

    Widget content = child;
    if (addHorizontalPadding) {
      content = Padding(
        padding: r.screenPadding,
        child: content,
      );
    }

    if (effectiveMaxWidth != double.infinity) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: content,
        ),
      );
    }

    return content;
  }
}
