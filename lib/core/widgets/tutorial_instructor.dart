import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Asset de la instructora del tutorial (personaje chibi militar, PNG con
/// transparencia real, ~460×750 px — sobra resolución hasta para tablets).
const String kTutorialInstructorAsset = 'assets/images/instructora_tutorial.png';

/// Instructora militar que guía los tutoriales: el personaje ilustrado de la
/// app en vez de un dibujo procedural. Está VIVA:
///
/// - Reposo: flota y se balancea suavemente en bucle (respira / saluda).
/// - [celebrate]: saltitos enérgicos de "misión cumplida" con sacudida.
/// - [entrance]: aparición elástica (pop desde los pies) al montarse — para
///   diálogos y presentaciones.
///
/// Solo anima transform + opacidad (propiedades del compositor): seguro en
/// web/CanvasKit y GPUs débiles. Con reduce-motion queda estática en su pose
/// neutral y la entrada salta directo al final.
class TutorialInstructor extends StatefulWidget {
  final double height;
  final bool celebrate;
  final bool entrance;

  const TutorialInstructor({
    super.key,
    required this.height,
    this.celebrate = false,
    this.entrance = false,
  });

  @override
  State<TutorialInstructor> createState() => _TutorialInstructorState();
}

class _TutorialInstructorState extends State<TutorialInstructor>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _pop;

  static const _idleCalm = Duration(milliseconds: 2600);
  static const _idleParty = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: widget.celebrate ? _idleParty : _idleCalm,
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    if (!widget.entrance) _pop.value = 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _idle.stop();
      _idle.value = 0;
      _pop.value = 1.0;
    } else {
      if (!_idle.isAnimating) _idle.repeat();
      if (_pop.value < 1.0 && !_pop.isAnimating) _pop.forward();
    }
  }

  @override
  void didUpdateWidget(covariant TutorialInstructor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.celebrate != widget.celebrate) {
      _idle.duration = widget.celebrate ? _idleParty : _idleCalm;
      if (_idle.isAnimating) _idle.repeat();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _pop]),
        builder: (context, child) {
          final phase = _idle.value * 2 * math.pi;
          final double dy;
          final double tilt;
          if (widget.celebrate) {
            // Dos saltitos por ciclo + sacudida rápida de festejo.
            dy = -math.sin(phase * 2).abs() * h * 0.055;
            tilt = math.sin(phase * 4) * 0.05;
          } else {
            // Flote respirado + balanceo apenas perceptible, desfasados para
            // que el movimiento no se sienta mecánico.
            dy = math.sin(phase) * h * 0.018;
            tilt = math.sin(phase + 0.8) * 0.022;
          }

          // Entrada elástica: crece desde los pies mientras aparece.
          final scale = 0.4 + 0.6 * Curves.elasticOut.transform(_pop.value);
          final opacity = (_pop.value * 3).clamp(0.0, 1.0);

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, dy),
              child: Transform.rotate(
                angle: tilt,
                alignment: Alignment.bottomCenter,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: Image.asset(
          kTutorialInstructorAsset,
          height: h,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
