import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/theme/theme_manager.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/utils/error_mapper.dart';

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

        try {
          final _progService = ProgramacionService();
          await _progService.verificarVersion();
        } catch (e) {
          // Si es error de versión, mostrar el mensaje del backend (contiene instrucciones de actualización)
          final raw = e.toString().replaceAll('Exception: ', '');
          final isVersionMsg = raw.toLowerCase().contains('versión') || raw.toLowerCase().contains('actualizar');
          setState(() {
            _isLoading = false;
            _errorMessage = isVersionMsg ? raw : ErrorMapper.message(e, context: ErrorContext.verificarVersion);
          });
          await TokenStorage.deleteToken();
          return;
        }

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
    final r = context.r;
    final texts = context.texts;

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
            width: MediaQuery.of(ctx).size.width * r.modalWidthFactor,
            constraints: BoxConstraints(maxWidth: r.modalMaxWidth),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(r.modalRadius),
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
                SizedBox(height: r.spaceXl),
                // Warning icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.shield_lefthalf_fill,
                    size: r.iconLg,
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(height: r.spaceMd),
                // Title
                Text(
                  'Advertencia de Seguridad',
                  style: texts.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: r.spaceSm),
                // Message
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.modalPadding),
                  child: Text(
                    'Por seguridad y confidencialidad de su información deberá cambiar su contraseña.',
                    style: texts.bodyMedium.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondaryC(isDark),
                      fontWeight: FontWeight.w400,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.modalPadding),
                  child: Text(
                    'Esta acción es obligatoria y no puede omitirse.',
                    style: texts.bodySmall.copyWith(
                      height: 1.4,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: r.spaceLg),
                // Button
                Padding(
                  padding: EdgeInsets.fromLTRB(r.modalPadding, 0, r.modalPadding, r.modalPadding),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(vertical: r.spaceMd),
                      borderRadius: BorderRadius.circular(r.buttonRadius),
                      color: AppColors.primary,
                      onPressed: () {
                        warningPlayer?.stop();
                        warningPlayer?.dispose();
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'Entendido, Continuar',
                        style: texts.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.35)
                                  : AppColors.textTertiary.withValues(alpha: 0.55),
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: context.r.spaceXs),
                          Text(
                            'COSSMIL',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.4)
                                  : AppColors.textTertiary.withValues(alpha: 0.6),
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: context.r.spaceXs),
                          Text(
                            '2026',
                            style: TextStyle(
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
                padding: EdgeInsets.all(context.r.spaceSm),
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
    final r = context.r;
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
        SizedBox(height: r.spaceXs),
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
    final r = context.r;
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
        SizedBox(height: r.spaceMd),
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
    final r = context.r;
    final texts = context.texts;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(r.inputRadius),
        border: Border.all(
          color: AppColors.cardBorder(isDark),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: r.cardPadding, vertical: r.spaceSm),
      child: Row(
        children: [
          Icon(icon, size: r.iconMd, color: AppColors.accentForTheme(isDark)),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: texts.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                CupertinoTextField(
                  controller: controller,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  padding: EdgeInsets.zero,
                  decoration: null,
                  placeholder: placeholder,
                  placeholderStyle: texts.bodyLarge.copyWith(
                    color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.6),
                  ),
                  style: texts.bodyLarge.copyWith(
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
            SizedBox(width: r.spaceXs),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.r.tileHorizontalPad, vertical: context.r.tileVerticalPad),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(context.r.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppColors.error,
            size: 20,
          ),
          SizedBox(width: context.r.spaceMd),
          Expanded(
            child: Text(
              _errorMessage!,
              style: context.texts.bodyMedium.copyWith(
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
            borderRadius: BorderRadius.circular(context.r.buttonRadius),
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


}
