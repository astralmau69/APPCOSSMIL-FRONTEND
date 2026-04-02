import 'package:flutter/material.dart';

/// Helpers y extensiones para layouts responsive sin código duplicado.
extension MediaQueryExtension on BuildContext {
  /// Get responsive theme easily
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

/// Data sobre el tamaño y categoría del dispositivo actual.
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
  
  // Convenience getters for specific phone sizes
  bool get isSmallPhone => deviceType == DeviceType.phoneSmall;
  bool get isMediumPhone => deviceType == DeviceType.phoneMedium;
  bool get isLargePhone => deviceType == DeviceType.phoneLarge;
}

/// Extensión para acceder a tipografía responsiva unificada desde el context.
/// Uso: context.texts.bodyLarge
extension TypographyExtension on BuildContext {
  ResponsiveTypography get texts => ResponsiveTypography.of(this);
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
  
  // BODY - Contenido principal (El estándar es 16pt, que con el scaler 1.25 llega a 20pt)
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
    final data = ResponsiveData.of(context);
    final effectiveMaxWidth = maxWidth ?? (data.isTablet ? 800 : double.infinity);

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}
