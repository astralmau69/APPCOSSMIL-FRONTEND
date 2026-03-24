import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/session_restore_service.dart';

class SplashScreen extends StatefulWidget {
  /// true = viene de segundo plano (no reproduce audio, duración breve).
  final bool isOverlay;
  const SplashScreen({super.key, this.isOverlay = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Background gradient — slow loop
  late final AnimationController _bgCtrl;

  // Logo: fade + spring scale
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  // One-shot expanding ripple ring around logo
  late final AnimationController _rippleCtrl;
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleOpacity;

  // Pulsing glow
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowOpacity;

  // Tagline beneath logo
  late final AnimationController _taglineCtrl;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;

  // Footer
  late final AnimationController _footerCtrl;
  late final Animation<double> _footerFade;

  AudioPlayer? _audioPlayer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      SystemChrome.setSystemUIOverlayStyle(
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
    });

    // Background — very slow, imperceptible color drift
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // Logo — spring entrance (easeOutBack gives a slight overshoot)
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );

    // Ripple — one-shot expanding ring, runs once when logo appears
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _rippleScale = Tween<double>(begin: 0.85, end: 1.55).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.18).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    // Tagline — slides up + fades in
    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _taglineFade = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn);
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOutCubic));

    // Footer
    _footerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _footerFade = CurvedAnimation(parent: _footerCtrl, curve: Curves.easeIn);

    _runSequence();
  }

  Future<void> _runSequence() async {
    // Brief pause to let the background start rendering
    await Future.delayed(const Duration(milliseconds: 180));

    if (!widget.isOverlay && mounted) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.play(AssetSource('vof/primer-vof.mp3'));
    }

    // Logo enters with spring feel
    if (!mounted) return;
    _logoCtrl.forward();

    // Ripple fires shortly after logo starts
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _rippleCtrl.forward();

    // Glow starts after ripple
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    _glowCtrl.repeat(reverse: true);

    // Tagline slides in
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _taglineCtrl.forward();

    // Footer version text
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    _footerCtrl.forward();

    // Hold time — let the user take it in
    if (widget.isOverlay) {
      await Future.delayed(const Duration(milliseconds: 1600));
    } else {
      await Future.delayed(const Duration(milliseconds: 3200));
    }

    // Graceful exit
    if (!mounted) return;
    _logoCtrl.reverse();
    _taglineCtrl.reverse();
    _footerCtrl.reverse();
    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted || _navigated) return;
    _navigate();
  }

  Future<void> _navigate() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    if (widget.isOverlay) {
      Navigator.pop(context);
    } else {
      final hasToken = await TokenStorage.hasToken();
      final hasPin = await SecurityService.hasPin();

      if (!mounted) return;

      if (hasToken) {
        final restored = await SessionRestoreService.restoreUserSession();
        if (!mounted) return;

        if (!restored) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        if (hasPin) {
          Navigator.pushReplacementNamed(context, '/local-auth');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _bgCtrl.dispose();
    _logoCtrl.dispose();
    _rippleCtrl.dispose();
    _glowCtrl.dispose();
    _taglineCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width * 0.45).clamp(150.0, 220.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: AnimatedBuilder(
        animation: _bgCtrl,
        builder: (context, child) {
          final t = _bgCtrl.value;
          return Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.6, 1.0],
                colors: isDark
                    ? [
                        Color.lerp(
                            const Color(0xFF0F172A), const Color(0xFF0C1426), t)!,
                        Color.lerp(
                            const Color(0xFF1A2540), const Color(0xFF162035), t)!,
                        Color.lerp(
                            const Color(0xFF0C4A6E), const Color(0xFF093E5C), t)!,
                      ]
                    : [
                        Color.lerp(
                            const Color(0xFFFFFFFF), const Color(0xFFF8FBFF), t)!,
                        Color.lerp(
                            const Color(0xFFF0F7FF), const Color(0xFFEAF3FF), t)!,
                        Color.lerp(
                            const Color(0xFFE8F4FD), const Color(0xFFDAEDFB), t)!,
                      ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              _buildLogo(context, logoSize),
              const SizedBox(height: 28),
              _buildTagline(context),
              const Spacer(flex: 4),
              _buildFooter(context),
              SizedBox(height: size.height * 0.05),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context, double logoSize) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _logoFade,
      child: ScaleTransition(
        scale: _logoScale,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Expanding ripple ring — fires once on logo entry.
            // Uses color alpha directly instead of Opacity widget to avoid
            // creating an expensive offscreen compositing buffer.
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (context, _) {
                final ringColor =
                    (isDark ? AppColors.razer : AppColors.primaryMedium)
                        .withValues(alpha: _rippleOpacity.value);
                return Transform.scale(
                  scale: _rippleScale.value,
                  child: Container(
                    width: logoSize + 24,
                    height: logoSize + 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ringColor, width: 2.0),
                    ),
                  ),
                );
              },
            ),
            // Pulsing glow halo
            AnimatedBuilder(
              animation: _glowOpacity,
              builder: (context, _) {
                return Container(
                  width: logoSize + 40,
                  height: logoSize + 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: _glowOpacity.value),
                        blurRadius: 36,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                );
              },
            ),
            // Logo body
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.10),
                    blurRadius: 28,
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
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : AppColors.primaryLight,
                      border: Border.all(
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.shield,
                      size: logoSize * 0.4,
                      color: isDark ? AppColors.white : AppColors.primary,
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

  Widget _buildTagline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _taglineFade,
      child: SlideTransition(
        position: _taglineSlide,
        child: Column(
          children: [
            Text(
              'COSSMIL',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 5.0,
                color: isDark ? AppColors.white : AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Corp. del Seguro Social Militar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.45)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _footerFade,
      child: Text(
        'FlowV1',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.white.withValues(alpha: 0.4)
              : AppColors.textTertiary.withValues(alpha: 0.6),
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
