import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Animated success indicator: ring draw → checkmark stroke → particle burst.
///
/// Self-contained — starts automatically on mount. Total duration ~1.6s.
class SuccessCheckAnimation extends StatefulWidget {
  final double size;
  final Color? color;

  const SuccessCheckAnimation({super.key, this.size = 100, this.color});

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _checkCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _scaleCtrl;

  late final Animation<double> _ringAnim;
  late final Animation<double> _checkAnim;
  late final Animation<double> _particleAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    // 1. Ring draws (0 → 1)
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut);

    // 2. Checkmark stroke
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeInOut);

    // 3. Particles burst out and fade
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _particleAnim = CurvedAnimation(
      parent: _particleCtrl,
      curve: Curves.easeOut,
    );

    // 4. Scale bounce on the whole widget
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Scale + ring at the same time
    _scaleCtrl.forward();
    await _ringCtrl.forward();
    // Haptic on check draw
    HapticFeedback.mediumImpact();
    // Checkmark + particles together
    _checkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact(); // Punchy finish
    _particleCtrl.forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _checkCtrl.dispose();
    _particleCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.accent;
    final size = widget.size;

    return SizedBox(
      width: size * 1.6,
      height: size * 1.6,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _ringAnim,
          _checkAnim,
          _particleAnim,
          _scaleAnim,
        ]),
        builder: (context, _) {
          return CustomPaint(
            painter: _SuccessPainter(
              color: color,
              ringProgress: _ringAnim.value,
              checkProgress: _checkAnim.value,
              particleProgress: _particleAnim.value,
              scale: _scaleAnim.value,
            ),
            size: Size(size * 1.6, size * 1.6),
          );
        },
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  final Color color;
  final double ringProgress;
  final double checkProgress;
  final double particleProgress;
  final double scale;

  _SuccessPainter({
    required this.color,
    required this.ringProgress,
    required this.checkProgress,
    required this.particleProgress,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.55;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    // ── Glow behind ring ──
    if (ringProgress > 0.5) {
      final glowOpacity =
          (ringProgress - 0.5) * 0.3 * (1 - particleProgress * 0.5);
      final glowPaint = Paint()
        ..color = color.withValues(alpha: glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(center, radius + 8, glowPaint);
    }

    // ── Ring (circle fill) ──
    if (ringProgress > 0) {
      // Background circle fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.12 * ringProgress)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);

      // Ring stroke
      final ringPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * ringProgress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        ringPaint,
      );
    }

    // ── Checkmark ──
    if (checkProgress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Checkmark points relative to center
      final p1 = Offset(center.dx - radius * 0.32, center.dy + radius * 0.02);
      final p2 = Offset(center.dx - radius * 0.05, center.dy + radius * 0.30);
      final p3 = Offset(center.dx + radius * 0.35, center.dy - radius * 0.25);

      final path = Path();

      // First segment: p1 → p2
      final seg1Length = (p2 - p1).distance;
      final seg2Length = (p3 - p2).distance;
      final totalLength = seg1Length + seg2Length;

      final drawnLength = checkProgress * totalLength;

      if (drawnLength <= seg1Length) {
        // Still drawing first segment
        final t = drawnLength / seg1Length;
        final current = Offset.lerp(p1, p2, t)!;
        path.moveTo(p1.dx, p1.dy);
        path.lineTo(current.dx, current.dy);
      } else {
        // First segment done, drawing second
        path.moveTo(p1.dx, p1.dy);
        path.lineTo(p2.dx, p2.dy);
        final t = (drawnLength - seg1Length) / seg2Length;
        final current = Offset.lerp(p2, p3, t)!;
        path.lineTo(current.dx, current.dy);
      }

      canvas.drawPath(path, checkPaint);
    }

    // ── Particles ──
    if (particleProgress > 0) {
      final rng = Random(42); // Fixed seed for consistent pattern
      const particleCount = 20; // Increased for a confetti feel
      final particleRadius = radius * 2.5;

      for (int i = 0; i < particleCount; i++) {
        final angle = (2 * pi / particleCount) * i + rng.nextDouble() * 0.5;
        // Ease out explosion distance
        final curveValue = particleProgress >= 1.0
            ? 1.0
            : 1.0 - pow(1.0 - particleProgress, 3);
        final dist =
            radius +
            (particleRadius - radius) *
                (0.4 + 0.6 * rng.nextDouble()) *
                curveValue;
        final opacity = (1.0 - particleProgress).clamp(0.0, 1.0);
        final dotSize = (3.0 + rng.nextDouble() * 3.5) * opacity;

        final pos = Offset(
          center.dx + cos(angle) * dist,
          center.dy + sin(angle) * dist,
        );

        // Mix accent color with gold/amber for confetti look
        final isGold = i % 3 == 0;
        final dotColor = isGold
            ? Colors.amber.withValues(alpha: opacity)
            : i.isEven
            ? color.withValues(alpha: opacity)
            : color.withValues(alpha: opacity * 0.6);

        canvas.drawCircle(pos, dotSize, Paint()..color = dotColor);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      ringProgress != old.ringProgress ||
      checkProgress != old.checkProgress ||
      particleProgress != old.particleProgress ||
      scale != old.scale;
}
