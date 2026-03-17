import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

const Color _white = Color(0xFFFFFFFF);
const Color _darkText = Color(0xFF1C1C1E);
const Color _subtleGrey = Color(0xFF8E8E93);
const Color _olive = Color(0xFF6B6830);

class SplashScreen extends StatefulWidget {
  final bool isOverlay;
  const SplashScreen({super.key, this.isOverlay = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Logo: fade + scale + pulso
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  // Anillo sutil rotativo
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringFade;

  // Texto principal
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  // Tagline
  late final AnimationController _taglineCtrl;
  late final Animation<double> _taglineFade;

  // Footer
  late final AnimationController _footerCtrl;
  late final Animation<double> _footerFade;

  // Partículas (dos capas parallax)
  late final AnimationController _particleFarCtrl;
  late final AnimationController _particleNearCtrl;

  // Audio
  late final AudioPlayer _audioPlayer;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    _audioPlayer = AudioPlayer();

    // Logo — scale 0.92→1.0 con easeOutExpo
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutExpo),
    );

    // Pulso final leve
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Anillo rotativo — aparece con fade después del logo
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _ringFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0, 0.08, curve: Curves.easeIn),
      ),
    );

    // Texto
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Tagline
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _taglineFade = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn);

    // Footer
    _footerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeIn);

    // Partículas — dos capas con velocidades distintas (parallax)
    _particleFarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
    _particleNearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Pausa: fondo + partículas visibles
    await Future.delayed(const Duration(milliseconds: 400));

    // Audio
    if (mounted) {
      _audioPlayer.play(AssetSource('vof/primer-vof.mp3'));
    }

    // Logo entra
    if (!mounted) return;
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));

    // Anillo aparece y empieza a girar
    if (!mounted) return;
    _ringCtrl.repeat();
    await Future.delayed(const Duration(milliseconds: 500));

    // Texto principal
    if (!mounted) return;
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 700));

    // Tagline
    if (!mounted) return;
    _taglineCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 600));

    // Footer
    if (!mounted) return;
    _footerCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // Pulso leve
    if (!mounted) return;
    await _pulseCtrl.forward();
    await _pulseCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 500));

    // Navegar
    if (mounted && !_navigated) {
      _navigated = true;
      if (widget.isOverlay) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    _footerCtrl.dispose();
    _particleFarCtrl.dispose();
    _particleNearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          // Gradiente radial muy sutil: blanco centro, gris cálido bordes
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              _white,
              const Color(0xFFF8F8F5),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Capa lejana de partículas (más pequeñas, más lentas)
            _buildParticleLayer(
              size,
              _particleFarCtrl,
              _farParticles,
              opacity: 0.04,
              blur: 4.0,
            ),
            // Capa cercana de partículas (más grandes, más rápidas)
            _buildParticleLayer(
              size,
              _particleNearCtrl,
              _nearParticles,
              opacity: 0.07,
              blur: 2.5,
            ),
            // Contenido principal
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildLogoWithRing(),
                  const SizedBox(height: 28),
                  _buildWelcomeText(),
                  const SizedBox(height: 32),
                  _buildTagline(),
                  const Spacer(flex: 3),
                  _buildFooter(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Partículas parallax ─────────────────────────────────────────────────
  Widget _buildParticleLayer(
    Size size,
    AnimationController ctrl,
    List<_Particle> particles, {
    required double opacity,
    required double blur,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _ParticlePainter(
            progress: ctrl.value,
            particles: particles,
            opacity: opacity,
            blur: blur,
          ),
        );
      },
    );
  }

  // ── Logo + anillo sutil ─────────────────────────────────────────────────
  Widget _buildLogoWithRing() {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Transform.scale(
            scale: _pulse.value,
            child: child,
          ),
          child: SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Anillo rotativo sutil
                AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _ringFade.value,
                      child: Transform.rotate(
                        angle: _ringCtrl.value * 2 * math.pi,
                        child: CustomPaint(
                          size: const Size(230, 230),
                          painter: _RingPainter(
                            color: _olive.withOpacity(0.12),
                            strokeWidth: 1.2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Sombra del logo
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.06),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Logo
                ClipOval(
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: Image.asset(
                      'assets/images/cossmil_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF5F5F5),
                          border: Border.all(
                            color: _subtleGrey.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.shield_fill,
                          size: 80,
                          color: _subtleGrey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return FadeTransition(
      opacity: _textFade,
      child: SlideTransition(
        position: _textSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Bienvenido al aplicativo móvil\nde citas médicas de\nCossmil',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _darkText,
              height: 1.4,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineFade,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Text(
          'INTEGRIDAD EN LA GESTIÓN Y\nTRANSPARENCIA QUE LA RESPALDA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w400,
            color: _subtleGrey,
            letterSpacing: 1.8,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _footerFade,
      child: Text(
        'FLOWV1.',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: _subtleGrey.withOpacity(0.6),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Datos de partículas ───────────────────────────────────────────────────
const _farParticles = <_Particle>[
  _Particle(0.08, 0.12, 2.5),
  _Particle(0.92, 0.08, 2.0),
  _Particle(0.15, 0.85, 3.0),
  _Particle(0.82, 0.88, 2.5),
  _Particle(0.45, 0.35, 1.8),
  _Particle(0.95, 0.45, 2.0),
  _Particle(0.05, 0.55, 2.2),
  _Particle(0.72, 0.18, 1.8),
  _Particle(0.30, 0.70, 2.5),
  _Particle(0.60, 0.92, 2.0),
];

const _nearParticles = <_Particle>[
  _Particle(0.12, 0.22, 3.5),
  _Particle(0.85, 0.15, 3.0),
  _Particle(0.22, 0.78, 4.0),
  _Particle(0.75, 0.80, 3.2),
  _Particle(0.50, 0.42, 2.8),
  _Particle(0.88, 0.55, 3.0),
];

// ── Pintor de partículas ──────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final double opacity;
  final double blur;

  _ParticlePainter({
    required this.progress,
    required this.particles,
    required this.opacity,
    required this.blur,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0B0B0).withOpacity(opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

    for (final p in particles) {
      final angle = progress * 2 * math.pi;
      final dy = math.sin(angle + p.x * 8) * 10;
      final dx = math.cos(angle + p.y * 6) * 7;

      canvas.drawCircle(
        Offset(p.x * size.width + dx, p.y * size.height + dy),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      progress != old.progress;
}

// ── Pintor del anillo sutil ───────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _RingPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    // Arco parcial — solo 270° para efecto elegante
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      3 * math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => color != old.color;
}

class _Particle {
  final double x;
  final double y;
  final double radius;
  const _Particle(this.x, this.y, this.radius);
}
