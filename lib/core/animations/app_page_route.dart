import 'package:flutter/cupertino.dart';

/// Custom page route utilizing highly optimized native slide + fade transitions.
/// Replaces the default MaterialPageRoute for a more polished and fluid feel.
/// Ahora delega a [CupertinoPageRoute] para asegurar swipe-back interactivo
/// nativo y máximo rendimiento en Impeller / Skia.
///
/// ```dart
/// Navigator.push(context, AppPageRoute(builder: (_) => NextScreen()));
/// ```
class AppPageRoute<T> extends CupertinoPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });
}
