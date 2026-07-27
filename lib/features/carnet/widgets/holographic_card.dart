import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:sensors_plus/sensors_plus.dart';

/// Tarjeta con efecto holográfico profesional: se inclina en 3D según el
/// movimiento del dispositivo (acelerómetro) y también al arrastrar con el
/// dedo. Sobre el contenido aplica un brillo holográfico (arcoíris + glare)
/// que se desplaza con la inclinación, como una tarjeta física plastificada.
class HolographicCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  /// Intensidad del brillo holográfico (0–1).
  final double shineStrength;

  /// Si es true, superpone un brillo holográfico en forma de panal de abeja
  /// (celdas hexagonales que cambian de color al inclinar), para integrarse con
  /// el diseño del carnet.
  final bool honeycombShimmer;

  const HolographicCard({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.shineStrength = 0.55,
    this.honeycombShimmer = false,
  });

  @override
  State<HolographicCard> createState() => _HolographicCardState();
}

class _HolographicCardState extends State<HolographicCard>
    with SingleTickerProviderStateMixin {
  // Inclinación objetivo (desde sensor/gesto) y actual (suavizada).
  double _targetX = 0, _targetY = 0;
  double _curX = 0, _curY = 0;

  // Inclinación manual por gesto (se desvanece al soltar).
  double _dragX = 0, _dragY = 0;
  bool _dragging = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  late final Ticker _ticker;

  static const double _maxTilt = 0.22; // ~12.5°

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen(_onAccel, onError: (_) {});
    } catch (_) {
      // Sin sensor (web/escritorio): solo gesto.
    }
  }

  void _onAccel(AccelerometerEvent e) {
    if (_dragging) return;
    // Gravedad ~9.8. x: izquierda/derecha, y: arriba/abajo.
    final ny = (e.x / 9.8).clamp(-1.0, 1.0);
    final nx = (e.y / 9.8).clamp(-1.0, 1.0);
    _targetY = (-ny) * _maxTilt; // rotación en Y según inclinación lateral
    _targetX =
        (nx - 0.55) * _maxTilt * 1.4; // compensa el ángulo natural de lectura
    _targetX = _targetX.clamp(-_maxTilt, _maxTilt);
  }

  void _onTick(Duration _) {
    final tx = _dragging ? _dragX : _targetX;
    final ty = _dragging ? _dragY : _targetY;
    // Suavizado (low-pass). Factor bajo = glide más sedoso al inclinar.
    final nextX = _curX + (tx - _curX) * 0.085;
    final nextY = _curY + (ty - _curY) * 0.085;
    // Deadzone: ignorar cambios mínimos (jitter del acelerómetro) para no
    // repintar en reposo y ahorrar batería/GPU.
    if ((nextX - _curX).abs() > 0.0015 || (nextY - _curY).abs() > 0.0015) {
      setState(() {
        _curX = nextX;
        _curY = nextY;
      });
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) => _dragging = true;

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    _dragX = ((d.localPosition.dy / size.height) - 0.5) * -2 * _maxTilt;
    _dragY = ((d.localPosition.dx / size.width) - 0.5) * 2 * _maxTilt;
    _dragX = _dragX.clamp(-_maxTilt, _maxTilt);
    _dragY = _dragY.clamp(-_maxTilt, _maxTilt);
  }

  void _onPanEnd(DragEndDetails _) {
    _dragging = false;
    _dragX = 0;
    _dragY = 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxWidth * 0.63);
        // Posición del brillo según inclinación.
        final shineAlign = Alignment(
          (_curY / _maxTilt).clamp(-1.0, 1.0),
          (-_curX / _maxTilt).clamp(-1.0, 1.0),
        );
        // Posición de la franja de reflejo (glare) que barre al inclinar.
        final glare = (0.5 + (_curY / _maxTilt) * 0.42).clamp(0.10, 0.90);
        double gp(double d) => (glare + d).clamp(0.0, 1.0);

        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(_curX)
          ..rotateY(_curY);

        // RepaintBoundary aísla los repintados continuos del holograma (tilt)
        // del resto de la pantalla (header, botones, etc.).
        return RepaintBoundary(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: (d) => _onPanUpdate(d, size),
            onPanEnd: _onPanEnd,
            child: Transform(
              alignment: Alignment.center,
              transform: transform,
              child: Stack(
                children: [
                  // Sombra dinámica que sigue la inclinación.
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 26,
                          offset: Offset(-_curY * 60, _curX * 60 + 14),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Stack(
                      children: [
                        // El contenido del carnet se cachea (RepaintBoundary): al
                        // inclinar solo se re-compone, no se vuelve a pintar.
                        RepaintBoundary(child: widget.child),
                        // 1) Tornasol holográfico (arcoíris) que cambia al inclinar.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                backgroundBlendMode: BlendMode.plus,
                                gradient: LinearGradient(
                                  begin: Alignment(
                                    -shineAlign.x,
                                    -shineAlign.y,
                                  ),
                                  end: shineAlign,
                                  colors: [
                                    const Color(0x00FFFFFF),
                                    const Color(0xFFFF2D9B).withValues(
                                      alpha: 0.16 * widget.shineStrength,
                                    ),
                                    const Color(0xFF7A5CFF).withValues(
                                      alpha: 0.16 * widget.shineStrength,
                                    ),
                                    const Color(0xFF00E0FF).withValues(
                                      alpha: 0.16 * widget.shineStrength,
                                    ),
                                    const Color(0xFF49FF8B).withValues(
                                      alpha: 0.16 * widget.shineStrength,
                                    ),
                                    const Color(0xFFFFE600).withValues(
                                      alpha: 0.16 * widget.shineStrength,
                                    ),
                                    const Color(0x00FFFFFF),
                                  ],
                                  stops: const [
                                    0.0,
                                    0.22,
                                    0.38,
                                    0.5,
                                    0.62,
                                    0.78,
                                    1.0,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 2) Franja de reflejo diagonal que barre la tarjeta.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                backgroundBlendMode: BlendMode.plus,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0x00FFFFFF),
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(
                                      alpha: 0.55 * widget.shineStrength,
                                    ),
                                    Colors.white.withValues(alpha: 0.0),
                                    const Color(0x00FFFFFF),
                                  ],
                                  stops: [
                                    0.0,
                                    gp(-0.16),
                                    gp(0.0),
                                    gp(0.16),
                                    1.0,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 3) Brillo especular suave que sigue la inclinación.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                backgroundBlendMode: BlendMode.softLight,
                                gradient: RadialGradient(
                                  center: shineAlign,
                                  radius: 1.0,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: 0.5 * widget.shineStrength,
                                    ),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.55],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 4) Panal de abeja holográfico (celdas que cambian de
                        //    color al inclinar) — integra el holograma con el
                        //    diseño del carnet.
                        if (widget.honeycombShimmer)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _HoneycombShimmerPainter(
                                  shift: glare,
                                  strength: widget.shineStrength,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Painter de patrón hexagonal (panal) para la cabecera del carnet.
class HoneycombPainter extends CustomPainter {
  final Color color;
  final double radius;

  HoneycombPainter({required this.color, this.radius = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    final w = radius * math.sqrt(3);
    final h = radius * 1.5;
    for (double y = -radius; y < size.height + radius; y += h) {
      final rowOffset = ((y ~/ h) % 2 == 0) ? 0.0 : w / 2;
      for (double x = -radius + rowOffset; x < size.width + radius; x += w) {
        _hexagon(canvas, Offset(x, y), radius, paint);
      }
    }
  }

  void _hexagon(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter old) =>
      old.color != color || old.radius != radius;
}

/// Panal de abeja holográfico: dibuja celdas hexagonales con colores de
/// arcoíris (mezcla aditiva) cuya tonalidad se desplaza con [shift] (la
/// inclinación), creando un brillo tornasol con forma de panal.
class _HoneycombShimmerPainter extends CustomPainter {
  final double shift; // 0..1 derivado de la inclinación
  final double strength; // 0..1

  _HoneycombShimmerPainter({required this.shift, required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    // Hexágonos pequeños para "casar" con el panal del propio carnet.
    final r = size.width * 0.038;
    final w = r * math.sqrt(3);
    final h = r * 1.5;
    final diag = size.width + size.height;
    // El brillo holográfico vive sobre la banda de diseño (parte superior) y se
    // desvanece sobre el área blanca de datos, integrándose con el carnet.
    final bandEnd = size.height * 0.50;
    final fadeEnd = size.height * 0.74;

    // Un solo Paint reutilizado (evita crear cientos de objetos por frame).
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..blendMode = BlendMode.plus;

    for (double y = -r; y < size.height + r; y += h) {
      // Factor de desvanecimiento según la zona del carnet.
      double zone;
      if (y <= bandEnd) {
        zone = 1.0;
      } else if (y >= fadeEnd) {
        zone = 0.12; // tenue sobre los datos, no los lava
      } else {
        zone = 1.0 - ((y - bandEnd) / (fadeEnd - bandEnd)) * 0.88;
      }
      final rowOffset = ((y ~/ h) % 2 == 0) ? 0.0 : w / 2;
      for (double x = -r + rowOffset; x < size.width + r; x += w) {
        final t = (((x + y) / diag) + shift) % 1.0;
        final hue = (t * 360.0) % 360.0;
        paint.color = HSVColor.fromAHSV(
          1.0,
          hue,
          0.82,
          1.0,
        ).toColor().withValues(alpha: 0.22 * strength * zone);
        _hex(canvas, Offset(x, y), r, paint);
      }
    }
  }

  void _hex(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _HoneycombShimmerPainter old) =>
      old.shift != shift || old.strength != strength;
}
