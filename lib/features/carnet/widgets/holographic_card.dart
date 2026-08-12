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

  /// Barrido de luz de entrada (0→1), opcional: una sola pasada de reflejo que
  /// cruza la tarjeta cuando aparece, como el destello de un plastificado al
  /// sacarlo de la billetera. Fuera del rango 0–1 la capa ni se construye.
  final Animation<double>? entrySweep;

  /// Proporción ancho/alto del contenido, solo para normalizar el arrastre del
  /// dedo a la inclinación. Por defecto la proporción ID-1 (tarjeta física).
  final double aspectRatio;

  const HolographicCard({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.shineStrength = 0.55,
    this.honeycombShimmer = false,
    this.entrySweep,
    this.aspectRatio = 1.586,
  });

  @override
  State<HolographicCard> createState() => _HolographicCardState();
}

class _HolographicCardState extends State<HolographicCard>
    with SingleTickerProviderStateMixin {
  // Inclinación objetivo (desde sensor/gesto). La actual vive en [_tilt] para
  // que el suavizado repinte SOLO las capas de brillo, no el carnet entero.
  double _targetX = 0, _targetY = 0;

  /// Inclinación suavizada: dx = rotación X, dy = rotación Y.
  final ValueNotifier<Offset> _tilt = ValueNotifier<Offset>(Offset.zero);

  // Inclinación manual por gesto (se desvanece al soltar).
  double _dragX = 0, _dragY = 0;
  bool _dragging = false;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  late final Ticker _ticker;

  /// Frames consecutivos sin movimiento apreciable. Al pasar de [_idleLimit]
  /// el ticker se detiene: en reposo el carnet no consume ni un frame.
  int _idleFrames = 0;
  static const int _idleLimit = 30; // ~0,5 s a 60 fps

  bool _reduceMotion = false;
  Size _size = Size.zero;

  static const double _maxTilt = 0.22; // ~12.5°

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduceMotion && _accelSub != null) return;
    _reduceMotion = reduce;
    if (_reduceMotion) {
      // Sin movimiento: nada de sensor ni ticker, y la tarjeta vuelve a plano.
      _accelSub?.cancel();
      _accelSub = null;
      if (_ticker.isActive) _ticker.stop();
      _tilt.value = Offset.zero;
      return;
    }
    _accelSub ??= _listenAccelerometer();
    _wake();
  }

  StreamSubscription<AccelerometerEvent>? _listenAccelerometer() {
    try {
      return accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 33),
      ).listen(_onAccel, onError: (_) {});
    } catch (_) {
      // Sin sensor (web/escritorio): solo gesto.
      return null;
    }
  }

  /// Reanuda el suavizado tras un reposo (nuevo dato del sensor o un gesto).
  void _wake() {
    if (_reduceMotion) return;
    _idleFrames = 0;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onAccel(AccelerometerEvent e) {
    if (_dragging) return;
    // Gravedad ~9.8. x: izquierda/derecha, y: arriba/abajo.
    final ny = (e.x / 9.8).clamp(-1.0, 1.0);
    final nx = (e.y / 9.8).clamp(-1.0, 1.0);
    final targetY = (-ny) * _maxTilt; // rotación en Y según inclinación lateral
    final targetX =
        ((nx - 0.55) * _maxTilt * 1.4) // compensa el ángulo natural de lectura
            .clamp(-_maxTilt, _maxTilt);
    // Solo despertar si el objetivo se movió de verdad: el acelerómetro emite
    // a 30 Hz aunque el equipo esté quieto sobre la mesa.
    if ((targetX - _targetX).abs() > 0.002 ||
        (targetY - _targetY).abs() > 0.002) {
      _targetX = targetX;
      _targetY = targetY;
      _wake();
    }
  }

  void _onTick(Duration _) {
    final cur = _tilt.value;
    final tx = _dragging ? _dragX : _targetX;
    final ty = _dragging ? _dragY : _targetY;
    // Suavizado (low-pass). Factor bajo = glide más sedoso al inclinar.
    final nextX = cur.dx + (tx - cur.dx) * 0.085;
    final nextY = cur.dy + (ty - cur.dy) * 0.085;
    // Deadzone: ignorar cambios mínimos (jitter del acelerómetro) para no
    // repintar en reposo y ahorrar batería/GPU.
    if ((nextX - cur.dx).abs() > 0.0015 || (nextY - cur.dy).abs() > 0.0015) {
      _idleFrames = 0;
      _tilt.value = Offset(nextX, nextY);
    } else if (!_dragging && ++_idleFrames >= _idleLimit) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker.dispose();
    _tilt.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails _) {
    if (_reduceMotion) return;
    _dragging = true;
    _wake();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_reduceMotion || _size.isEmpty) return;
    _dragX = (((d.localPosition.dy / _size.height) - 0.5) * -2 * _maxTilt)
        .clamp(-_maxTilt, _maxTilt);
    _dragY = (((d.localPosition.dx / _size.width) - 0.5) * 2 * _maxTilt).clamp(
      -_maxTilt,
      _maxTilt,
    );
    _wake();
  }

  void _onPanEnd(DragEndDetails _) {
    _dragging = false;
    _dragX = 0;
    _dragY = 0;
    _wake();
  }

  @override
  Widget build(BuildContext context) {
    // El carnet se construye UNA vez y viaja como `child` del AnimatedBuilder:
    // al inclinar solo se recomponen las capas de brillo.
    final Widget card = RepaintBoundary(child: widget.child);
    final sweep = widget.entrySweep;
    final Listenable driver = sweep == null
        ? _tilt
        : Listenable.merge([_tilt, sweep]);

    return LayoutBuilder(
      builder: (context, c) {
        _size = Size(c.maxWidth, c.maxWidth / widget.aspectRatio);
        // RepaintBoundary aísla los repintados continuos del holograma (tilt)
        // del resto de la pantalla (header, botones, etc.).
        return RepaintBoundary(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: driver,
              child: card,
              builder: (context, cardChild) =>
                  _buildSurface(cardChild!, sweep?.value ?? 1.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurface(Widget card, double sweepV) {
    final tilt = _tilt.value;
    final curX = tilt.dx, curY = tilt.dy;

    // Posición del brillo según inclinación.
    final shineAlign = Alignment(
      (curY / _maxTilt).clamp(-1.0, 1.0),
      (-curX / _maxTilt).clamp(-1.0, 1.0),
    );
    // Posición de la franja de reflejo (glare) que barre al inclinar.
    final glare = (0.5 + (curY / _maxTilt) * 0.42).clamp(0.10, 0.90);
    double gp(double d) => (glare + d).clamp(0.0, 1.0);

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(curX)
      ..rotateY(curY);

    return Transform(
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
                  offset: Offset(-curY * 60, curX * 60 + 14),
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
                card,
                // 1) Tornasol holográfico (arcoíris) que cambia al inclinar.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.plus,
                        gradient: LinearGradient(
                          begin: Alignment(-shineAlign.x, -shineAlign.y),
                          end: shineAlign,
                          colors: [
                            const Color(0x00FFFFFF),
                            const Color(
                              0xFFFF2D9B,
                            ).withValues(alpha: 0.16 * widget.shineStrength),
                            const Color(
                              0xFF7A5CFF,
                            ).withValues(alpha: 0.16 * widget.shineStrength),
                            const Color(
                              0xFF00E0FF,
                            ).withValues(alpha: 0.16 * widget.shineStrength),
                            const Color(
                              0xFF49FF8B,
                            ).withValues(alpha: 0.16 * widget.shineStrength),
                            const Color(
                              0xFFFFE600,
                            ).withValues(alpha: 0.16 * widget.shineStrength),
                            const Color(0x00FFFFFF),
                          ],
                          stops: const [0.0, 0.22, 0.38, 0.5, 0.62, 0.78, 1.0],
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
                          stops: [0.0, gp(-0.16), gp(0.0), gp(0.16), 1.0],
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
                // 5) Barrido de entrada: una sola pasada de luz al aparecer.
                if (sweepV > 0.0 && sweepV < 1.0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _EntrySweep(
                        progress: sweepV,
                        strength: widget.shineStrength,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Franja de luz que cruza la tarjeta una sola vez al aparecer. La banda entra
/// por fuera del borde izquierdo y sale por el derecho, y su intensidad sube y
/// baja para que el destello no aparezca ni se corte de golpe.
class _EntrySweep extends StatelessWidget {
  final double progress; // 0→1
  final double strength;

  const _EntrySweep({required this.progress, required this.strength});

  @override
  Widget build(BuildContext context) {
    // La banda recorre de -0,3 a 1,3 para entrar y salir fuera de cuadro.
    final pos = -0.3 + progress * 1.6;
    // Campana de intensidad: 0 → 1 → 0 a lo largo del recorrido.
    final fade = math.sin(progress * math.pi);
    final alpha = (0.62 * strength * fade).clamp(0.0, 1.0);
    double at(double d) => (pos + d).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        backgroundBlendMode: BlendMode.plus,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0x00FFFFFF),
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: alpha),
            Colors.white.withValues(alpha: 0.0),
            const Color(0x00FFFFFF),
          ],
          stops: [0.0, at(-0.10), at(0.0), at(0.10), 1.0],
        ),
      ),
    );
  }
}

/// Vértices de un hexágono de radio 1 con la punta hacia arriba (ángulos
/// 60·i − 30°). Precalculados: trazar el panal hacía doce llamadas
/// trigonométricas por celda, y el carnet dibuja varios cientos de celdas.
const List<Offset> _kHexUnit = [
  Offset(0.8660254037844387, -0.5),
  Offset(0.8660254037844387, 0.5),
  Offset(0.0, 1.0),
  Offset(-0.8660254037844387, 0.5),
  Offset(-0.8660254037844387, -0.5),
  Offset(0.0, -1.0),
];

/// Traza sobre [path] un hexágono de radio [r] centrado en [c].
void addHexagon(Path path, Offset c, double r) {
  for (var i = 0; i < 6; i++) {
    final u = _kHexUnit[i];
    final x = c.dx + r * u.dx;
    final y = c.dy + r * u.dy;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
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
    // Un solo Path reutilizado: el panal del carnet son varios cientos de
    // celdas y antes cada una creaba el suyo.
    final path = Path();
    for (double y = -radius; y < size.height + radius; y += h) {
      final rowOffset = ((y ~/ h) % 2 == 0) ? 0.0 : w / 2;
      for (double x = -radius + rowOffset; x < size.width + radius; x += w) {
        path.reset();
        addHexagon(path, Offset(x, y), radius);
        canvas.drawPath(path, paint);
      }
    }
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

  /// Arcoíris precalculado, un color por grado de tono. Convertir HSV→RGB para
  /// cada celda del panal en cada frame del inclinado era el grueso del coste
  /// de este painter (cientos de conversiones y objetos por frame).
  static final List<Color> _hueLut = List<Color>.generate(
    360,
    (i) => HSVColor.fromAHSV(1.0, i.toDouble(), 0.82, 1.0).toColor(),
    growable: false,
  );

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

    // Un solo Paint y un solo Path reutilizados (evitan crear cientos de
    // objetos por frame).
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true
      ..blendMode = BlendMode.plus;
    final path = Path();

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
      // El alfa solo depende de la fila (zone): se calcula una vez por fila.
      final alpha = 0.22 * strength * zone;
      final rowOffset = ((y ~/ h) % 2 == 0) ? 0.0 : w / 2;
      for (double x = -r + rowOffset; x < size.width + r; x += w) {
        final t = (((x + y) / diag) + shift) % 1.0;
        final hue = (t * 360.0).floor() % 360;
        paint.color = _hueLut[hue].withValues(alpha: alpha);
        path.reset();
        addHexagon(path, Offset(x, y), r);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HoneycombShimmerPainter old) =>
      old.shift != shift || old.strength != strength;
}
