import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  /// true = viene de segundo plano (no reproduce audio, duración breve).
  final bool isOverlay;
  const SplashScreen({super.key, this.isOverlay = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo: fade + scale
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // Glow pulse alrededor del logo
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowOpacity;

  // Footer
  late final AnimationController _footerCtrl;
  late final Animation<double> _footerFade;

  // Fade out general
  late final AnimationController _fadeOutCtrl;
  late final Animation<double> _fadeOut;

  // Audio
  AudioPlayer? _audioPlayer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    // Logo — entrada suave
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );

    // Glow sutil pulsante
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.15).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Footer
    _footerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeIn);

    // Fade out para transición elegante
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Solo reproducir audio en apertura real (no overlay / segundo plano)
    if (!widget.isOverlay && mounted) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.play(AssetSource('vof/primer-vof.mp3'));
    }

    // Logo entra
    if (!mounted) return;
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    // Glow pulse
    if (!mounted) return;
    _glowCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 300));

    // Footer
    if (!mounted) return;
    _footerCtrl.forward();

    if (widget.isOverlay) {
      // Breve splash sin audio
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      // Esperar a que el audio termine (o un mínimo razonable)
      await Future.delayed(const Duration(milliseconds: 4000));
    }

    // Fade out y navegar
    if (!mounted || _navigated) return;
    await _fadeOutCtrl.forward();
    _navigate();
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (widget.isOverlay) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    _footerCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = size.width * 0.45;
    final maxLogo = logoSize.clamp(150.0, 220.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: FadeTransition(
        opacity: _fadeOut,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF0F7FF),
                Color(0xFFE8F4FD),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                _buildLogo(maxLogo),
                const Spacer(flex: 4),
                _buildFooter(),
                SizedBox(height: size.height * 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double logoSize) {
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Composited glow pulse (saves GPU from recalculating 40px blur per frame)
            FadeTransition(
              opacity: _glowOpacity,
              child: Container(
                width: logoSize + 40,
                height: logoSize + 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary,
                      blurRadius: 32,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            // Static Logo Body
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.08),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/cossmil_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.shield,
                      size: logoSize * 0.4,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return FadeTransition(
      opacity: _footerFade,
      child: Text(
        'FlowV1',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary.withValues(alpha: 0.7),
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
