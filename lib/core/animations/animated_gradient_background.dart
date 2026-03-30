import 'package:flutter/material.dart';

/// Subtle animated gradient background.
/// Slowly shifts colors (8s cycle) to give a living, premium feel without jank.
/// For CAMBIO 6: apply to lock screen, login, and key UI surfaces.
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final Duration duration;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    required this.isDark,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground> {

  @override
  Widget build(BuildContext context) {
    // Solid background — no gradient per Design System "Clinical Serenity".
    return Container(
      color: widget.isDark
          ? const Color(0xFF101214)  // darkBackground
          : const Color(0xFFF7F9FB), // surface base
      child: widget.child,
    );
  }
}
