import 'package:flutter/cupertino.dart';

/// Custom page route utilizing native iOS slide transitions.
/// Replaces the default MaterialPageRoute for a more polished feel.
///
/// ```dart
/// Navigator.push(context, AppPageRoute(builder: (_) => NextScreen()));
/// ```
class AppPageRoute<T> extends CupertinoPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
  });
}
