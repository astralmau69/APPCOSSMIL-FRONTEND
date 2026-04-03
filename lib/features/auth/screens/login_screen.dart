import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/theme/theme_manager.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  AudioPlayer? _audioPlayer;

  late final AnimationController _logoCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotate;
  late final Animation<Offset> _logoFloat;

  @override
  void initState() {
    super.initState();
    // Entrada inicial
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Animación continua de flotación
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoRotate = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _logoFloat = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 0.05),
    ).animate(
      CurvedAnimation(
        parent: _floatCtrl,
        curve: Curves.easeInOutSine,
      ),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _logoCtrl.forward();
        _floatCtrl.repeat(reverse: true);
        _playLoginAudio();
      }
    });
  }

  Future<void> _playLoginAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(AssetSource('vof/AUDIO 2. LOGIN.mp3'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _logoCtrl.dispose();
    _floatCtrl.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Ingrese su matrícula y clave.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final token):
        if (!mounted) return;

        // Primer ingreso: forzar cambio de contraseña
        // reqReset == false → no ha cambiado, debe cambiar
        if (!token.reqReset) {
          await _showSecurityWarningModal();
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }

      case AuthError(:final message):
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
    }
  }

  Future<void> _showSecurityWarningModal() async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reproducir audio de advertencia de seguridad
    AudioPlayer? warningPlayer;
    try {
      warningPlayer = AudioPlayer();
      await warningPlayer.play(AssetSource('vof/AUDIO 3. ADVERTENCIA DE SEGURIDAD.mp3'));
    } catch (_) {}

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Advertencia de Seguridad',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.88,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 28),
                // Warning icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.shield_lefthalf_fill,
                    size: 36,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Advertencia de Seguridad',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 12),
                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Por seguridad y confidencialidad de su información deberá cambiar su contraseña.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Esta acción es obligatoria y no puede omitirse.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                // Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.primary,
                      onPressed: () {
                        warningPlayer?.stop();
                        warningPlayer?.dispose();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Entendido, Continuar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.white,
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

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/password-change');
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final logoSize = r.isSmallPhone ? 190.0
        : r.isMediumPhone ? 220.0
        : 250.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        isDark: isDark,
        child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: r.screenPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: r.screenHeight - MediaQuery.of(context).padding.vertical,
            ),
            child: Center(
              child: ResponsiveContainer(
                maxWidth: r.isTablet ? 450 : double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: r.spaceLg),
                    // Logo — entrance animations + continuous float
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: RotationTransition(
                          turns: _logoRotate,
                          child: SlideTransition(
                            position: _logoFloat,
                            child: _buildLogo(logoSize, isDark),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: r.spaceXl),

                    // Header
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      delay: const Duration(milliseconds: 100),
                      child: _buildHeader(isDark),
                    ),

                    SizedBox(height: r.spaceXxl),

                    // Form
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 200),
                      child: _buildForm(isDark),
                    ),

                    SizedBox(height: r.spaceLg),

                    // Error message
                    if (_errorMessage != null) ...[
                      FadeSlideIn(
                        duration: AppDurations.fast,
                        child: _buildErrorBanner(),
                      ),
                      SizedBox(height: r.spaceMd),
                    ],

                    // Login button
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 250),
                      child: _buildLoginButton(),
                    ),

                    SizedBox(height: r.spaceXl),

                    // Forgot password
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 300),
                      child: _buildForgotPassword(),
                    ),

                    SizedBox(height: r.spaceXxl),

                    // Footer
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 350),
                      child: Column(
                        children: [
                          Text(
                            'Dirección Nacional de Sistemas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.35)
                                  : AppColors.textTertiary.withValues(alpha: 0.55),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'COSSMIL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.4)
                                  : AppColors.textTertiary.withValues(alpha: 0.6),
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '2026',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.25)
                                  : AppColors.textTertiary.withValues(alpha: 0.4),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.spaceLg),
                  ],
                ),
              ),
            ),
          ),
        ),
            // Theme toggle button — top left
            Positioned(
              top: 8,
              right: 8,
              child: CupertinoButton(
                padding: const EdgeInsets.all(10),
                onPressed: () => ThemeManager.toggleTheme(),
                child: Icon(
                  isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                  size: 34,
                  color: AppColors.textSecondaryC(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildLogo(double size, bool isDark) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/cossmil_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          CupertinoIcons.shield_fill,
          size: size * 0.5,
          color: AppColors.accentForTheme(isDark),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final texts = context.texts;
    return Column(
      children: [
        Text(
          'Bienvenido',
          style: texts.displayLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryC(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingrese su matrícula y el código ubicado en la parte posterior de su carnet de asegurado',
          style: texts.bodyMedium.copyWith(
            color: AppColors.textSecondaryC(isDark),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    return Column(
      children: [
        _buildModernInputField(
          label: 'Matrícula',
          controller: _usernameController,
          placeholder: 'Ej. 010325AQJ',
          icon: CupertinoIcons.person_crop_circle,
          isDark: isDark,
          textCapitalization: TextCapitalization.characters,
          onChanged: (val) {
            if (val != val.toUpperCase()) {
              _usernameController.value = _usernameController.value.copyWith(
                text: val.toUpperCase(),
                selection: _usernameController.selection,
              );
            }
          },
        ),
        const SizedBox(height: 16),
        _buildModernInputField(
          label: 'Contraseña',
          controller: _passwordController,
          placeholder: 'Codigo o Contraseña',
          icon: CupertinoIcons.lock_fill,
          obscureText: _obscurePassword,
          isDark: isDark,
          isLast: true,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    bool isLast = false,
    bool isDark = false,
    Widget? trailing,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.cardBorder(isDark),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.accentForTheme(isDark)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.texts.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: controller,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  padding: EdgeInsets.zero,
                  decoration: null,
                  placeholder: placeholder,
                  placeholderStyle: TextStyle(
                    color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.6),
                    fontSize: 16,
                  ),
                  style: context.texts.bodyLarge.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: isLast ? (_) => _onLoginPressed() : null,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: context.r.buttonHeight,
      child: OptimizedPressButton(
        onTap: _isLoading ? null : _onLoginPressed,
        scaleDown: 0.95,
        child: Container(
          decoration: BoxDecoration(
            color: _isLoading ? AppColors.textSecondary : AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.15),
              width: 0.8,
            ),
            boxShadow: _isLoading ? [] : AppColors.softShadow,
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(
                    'Iniciar Sesión',
                    style: context.texts.titleMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {},
        child: Text(
          '¿Olvidó su contraseña?',
          style: context.texts.bodyMedium.copyWith(
            color: AppColors.accentForTheme(isDark),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
