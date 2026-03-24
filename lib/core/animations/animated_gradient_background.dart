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
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = _ctrl.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.55, 1.0],
              colors: widget.isDark
                  ? [
                      Color.lerp(
                          const Color(0xFF0A0A0F), const Color(0xFF0C0D17), t)!,
                      Color.lerp(
                          const Color(0xFF121219), const Color(0xFF0F1222), t)!,
                      Color.lerp(
                          const Color(0xFF0E1828), const Color(0xFF091525), t)!,
                    ]
                  : [
                      Color.lerp(
                          const Color(0xFFFFFFFF), const Color(0xFFF8FAFF), t)!,
                      Color.lerp(
                          const Color(0xFFF5F9FF), const Color(0xFFEEF4FF), t)!,
                      Color.lerp(
                          const Color(0xFFECF4FF), const Color(0xFFE4EFFF), t)!,
                    ],
            ),
          ),
          child: child,
        );
      },
      // RepaintBoundary isolates the content tree from the gradient's
      // per-frame repaints, preventing unnecessary child repaints.
      child: RepaintBoundary(child: widget.child),
    );
  }
}
