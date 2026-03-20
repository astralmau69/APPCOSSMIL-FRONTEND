import 'package:flutter/material.dart';

/// Envuelve un hijo con entrada animada fade+slide, util para items de lista.
///
/// Usa [FadeTransition] y [SlideTransition] (compositing-optimized)
/// en vez de [Opacity] + [Transform.translate] para evitar saveLayer.
///
/// Uso individual:
/// ```dart
/// FadeSlideIn(
///   delay: Duration(milliseconds: 100 * index),
///   child: MyWidget(),
/// )
/// ```
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.offsetY = 20.0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slideOffset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    _opacity = curved;
    // SlideTransition uses fractional offsets relative to child size.
    // Convert pixel offsetY to a reasonable fraction (offsetY / 100).
    _slideOffset = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slideOffset,
          child: widget.child,
        ),
      ),
    );
  }
}
