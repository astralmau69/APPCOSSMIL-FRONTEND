import 'package:flutter/material.dart';

/// Custom page route with smooth fade + upward slide transition.
/// Replaces the default MaterialPageRoute for a more polished feel.
///
/// ```dart
/// Navigator.push(context, AppPageRoute(builder: (_) => NextScreen()));
/// ```
class AppPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  AppPageRoute({
    required this.builder,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}
