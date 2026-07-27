import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_constants.dart';
import '../theme/sound_manager.dart';

/// Animación de entrada fade + slide optimizada para listas (sin animate_do dependency).
/// Usa compositing-optimized FadeTransition + SlideTransition + RepaintBoundary.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offsetY;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = AppDurations.normal,
    this.delay = Duration.zero,
    this.offsetY = 20.0,
    this.curve = Curves.easeOutCubic, // Curva orgánica y suave
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offsetY / 100),
      end: Offset.zero,
    ).animate(curvedAnimation);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      alwaysIncludeSemantics: true,
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        // RepaintBoundary aísla este widget durante la animación,
        // evitando que hermanos o el layout superior se repinten.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// Botón con feedback táctil animado - escala + fade ligero.
/// Optimizado para ser const en la mayoría de casos.
class OptimizedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;
  final Duration duration;
  final bool haptic;

  /// Sonido a reproducir al pulsar (una constante de `AppSounds`). Nulo por
  /// defecto: este botón envuelve también tarjetas de listas largas, y
  /// sonorizarlas todas volvería ruidosa la app. Se activa solo en acciones
  /// principales.
  final String? sound;

  const OptimizedPressButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
    this.duration = AppDurations.fast,
    this.haptic = false,
    this.sound,
  });

  @override
  State<OptimizedPressButton> createState() => _OptimizedPressButtonState();
}

class _OptimizedPressButtonState extends State<OptimizedPressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _controller.forward();
      if (widget.haptic) {
        HapticFeedback.selectionClick();
      }
      // En tapDown, no en tapUp: el sonido debe llegar con el dedo, igual que
      // el háptico. Esperar a soltar lo haría sentir retrasado.
      final s = widget.sound;
      if (s != null) SoundManager.playUi(s, volume: 0.5);
    }
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      // Pure ScaleTransition — avoids Impeller SetInheritedOpacity errors
      // that happen when FadeTransition wraps children with BoxShadow.
      child: ScaleTransition(
        scale: _scaleAnimation,
        // RepaintBoundary mejora touch-feedback responsiveness
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// Animación de cambio de opacidad + color - para status badges.
class OptimizedColorTween extends StatefulWidget {
  final Color startColor;
  final Color endColor;
  final Duration duration;
  final Widget Function(Color) builder;

  const OptimizedColorTween({
    super.key,
    required this.startColor,
    required this.endColor,
    required this.builder,
    this.duration = AppDurations.normal,
  });

  @override
  State<OptimizedColorTween> createState() => _OptimizedColorTweenState();
}

class _OptimizedColorTweenState extends State<OptimizedColorTween>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _colorAnimation = ColorTween(
      begin: widget.startColor,
      end: widget.endColor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void didUpdateWidget(OptimizedColorTween oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endColor != widget.endColor) {
      _controller.reverse().then((_) {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, _) =>
          widget.builder(_colorAnimation.value ?? widget.startColor),
    );
  }
}

/// Transición de página optimizada (Cupertino style, iOS).
class OptimizedPageRoute<T> extends MaterialPageRoute<T> {
  OptimizedPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => AppDurations.normal;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}
