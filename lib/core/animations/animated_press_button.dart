import 'package:flutter/material.dart';

/// Botón con feedback táctil animado: scale down + slight shadow on press.
/// Envuelve cualquier widget hijo con una sensación de "pressed" responsiva.
///
/// Uso:
/// ```dart
/// AnimatedPressButton(
///   onTap: () => doSomething(),
///   child: Container(...),
/// )
/// ```
class AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;

  const AnimatedPressButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.94,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  State<AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) _ctrl.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.reverse();
  }

  void _onTapCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      // Pure ScaleTransition — avoids Impeller SetInheritedOpacity errors
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.child,
      ),
    );
  }
}
