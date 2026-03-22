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
