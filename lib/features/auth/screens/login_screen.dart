import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/sound_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/theme/theme_manager.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/session_restore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _scrollController = ScrollController();
  final _authService = AuthService();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  AuthErrorType _errorType = AuthErrorType.unknown;
  String _appVersion = '1.0.2'; // fallback; se sobreescribe con PackageInfo
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

    // Animación continua de flotación — se pausa cuando el teclado abre
    // para liberar GPU en dispositivos antiguos.
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

    // Pausar flotación al abrir teclado — libera GPU en dispositivos viejos.
    _usernameFocus.addListener(_onFocusChanged);
    _passwordFocus.addListener(_onFocusChanged);

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _logoCtrl.forward();
        _floatCtrl.repeat(reverse: true);
        _playLoginAudio();
      }
    });

    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    }).catchError((_) {}); // old devices can throw here
  }

  /// Pausa la animación de flotación cuando el teclado está activo y la reanuda
  /// al cerrar, reduciendo la carga de GPU en dispositivos de gama baja.
  /// Se difiere con addPostFrameCallback para evitar mutaciones mid-frame
  /// que en Android antiguo causan el bucle de foco abierto/cerrado.
  void _onFocusChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_usernameFocus.hasFocus || _passwordFocus.hasFocus) {
        if (_floatCtrl.isAnimating) _floatCtrl.stop();
      } else {
        if (!_floatCtrl.isAnimating) _floatCtrl.repeat(reverse: true);
      }
    });
  }


  Future<void> _playLoginAudio() async {
    _audioPlayer = await SoundManager.playIfAllowed('vof/AUDIO 2. LOGIN.mp3');
  }

  void _showVersionModal(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.cardBg(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: AppColors.warning, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nueva version disponible',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu aplicacion necesita actualizarse para continuar usando COSSMIL.',
                style: TextStyle(color: AppColors.textSecondaryC(isDark), height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Visita el sitio web oficial de COSSMIL y descarga la ultima version desde ahi.',
                style: TextStyle(color: AppColors.textSecondaryC(isDark), height: 1.4),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.language_rounded, size: 18),
                label: const Text(
                  'Actualizar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () => launchUrl(
                  Uri.parse('https://www.cossmil.mil.bo/#/'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameFocus.removeListener(_onFocusChanged);
    _passwordFocus.removeListener(_onFocusChanged);
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _logoCtrl.dispose();
    _floatCtrl.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty && password.isEmpty) {
      setState(() { _errorMessage = 'Ingresa tu matrícula y contraseña para continuar.'; _errorType = AuthErrorType.unknown; });
      return;
    }
    if (username.isEmpty) {
      setState(() { _errorMessage = 'Ingresa tu matrícula.'; _errorType = AuthErrorType.unknown; });
      return;
    }
    if (password.isEmpty) {
      setState(() { _errorMessage = 'Ingresa tu contraseña.'; _errorType = AuthErrorType.unknown; });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorType = AuthErrorType.unknown;
    });

    final result = await _authService.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final token):
        // Verificar version DESPUÉS del login porque el endpoint requiere Bearer token
        try {
          await ProgramacionService().verificarVersion();
        } on VersionOutdatedException catch (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          // Borrar credenciales porque la app está desactualizada
          await TokenStorage.deleteToken();
          _showVersionModal(e.message);
          return;
        } catch (_) {
          // Error de red: dejar pasar.
        }

        if (!mounted) return;

        // Guardar credenciales cifradas para re-login silencioso en desbloqueo.
        await SessionRestoreService.storeCredentials(username, password);

        if (!mounted) return;

        // Ya NO habilitamos la biometría automáticamente. 
        // El usuario debe hacerlo manualmente desde la configuración de seguridad.

        if (!mounted) return;

        // Primer ingreso: forzar cambio de contraseña
        // reqReset == false → no ha cambiado, debe cambiar
        if (!token.reqReset) {
          await _showSecurityWarningModal();
        } else {
          Navigator.pushReplacementNamed(context, '/loading-data');
        }

      case AuthError(:final message, :final type):
        setState(() {
          _isLoading = false;
          _errorMessage = message;
          _errorType = type;
        });
    }
  }

  Future<void> _showSecurityWarningModal() async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;

    // Reproducir audio de advertencia de seguridad (respeta modo silencio/vibración)
    final warningPlayer = await SoundManager.playIfAllowed('vof/AUDIO 3. ADVERTENCIA DE SEGURIDAD.mp3');

    if (!mounted) return;
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
                  width: r.avatarMd,
                  height: r.avatarMd,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double logoSize = (r.screenHeight * 0.17).clamp(70.0, 140.0);
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool keyboardVisible = keyboardHeight > 80;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101214) : const Color(0xFFF7F9FB),
      // adjustNothing en el manifest + false aquí = Flutter recibe viewInsets
      // correctos sin que Android encoja la ventana, evitando el bug de MagicOS
      // donde el resize del Scaffold interrumpe el IME y cierra el teclado.
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: AnimatedGradientBackground(
          isDark: isDark,
          child: SafeArea(
            child: Stack(
              children: [
                // ── Layout principal: scroll + footer anclado ─────────────
                Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Cuando el teclado está visible, el área realmente
                          // visible encima del teclado es constraints.maxHeight
                          // menos keyboardHeight. Usar esa altura como minHeight
                          // evita que el Column intente llenar el espacio detrás
                          // del teclado, previniendo el "Bottom Overflowed".
                          final visibleHeight = keyboardVisible
                              ? (constraints.maxHeight - keyboardHeight)
                                  .clamp(0.0, constraints.maxHeight)
                              : constraints.maxHeight;
                          return SingleChildScrollView(
                          controller: _scrollController,
                          physics: const ClampingScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            r.paddingH,
                            keyboardVisible ? 12 : 8,
                            r.paddingH,
                            keyboardVisible ? keyboardHeight + 24 : 0,
                          ),
                          // En web/escritorio la pantalla es muy ancha; sin un
                          // tope de ancho el formulario (crossAxisAlignment.stretch)
                          // se estira a toda la pantalla. Lo centramos y limitamos
                          // a un ancho tipo móvil. En teléfonos el ancho real es
                          // menor que maxWidth → no cambia nada.
                          child: Center(
                            child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: visibleHeight,
                              maxWidth: 440,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: RepaintBoundary(
                                    child: FadeTransition(
                                      opacity: _logoFade,
                                      child: ScaleTransition(
                                        scale: _logoScale,
                                        child: RotationTransition(
                                          turns: _logoRotate,
                                          child: SlideTransition(
                                            position: _logoFloat,
                                            child: _buildLogo(
                                              keyboardVisible ? logoSize * 0.65 : logoSize,
                                              isDark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: keyboardVisible ? r.spaceSm : r.spaceMd),
                                if (!keyboardVisible || r.screenHeight > 700)
                                  FadeSlideIn(
                                    duration: AppDurations.slow,
                                    delay: const Duration(milliseconds: 100),
                                    child: _buildHeader(isDark),
                                  ),
                                SizedBox(height: keyboardVisible ? r.spaceMd : r.spaceXl),
                                FadeSlideIn(
                                  duration: AppDurations.normal,
                                  delay: const Duration(milliseconds: 200),
                                  child: _buildForm(isDark),
                                ),
                                SizedBox(height: r.spaceMd),
                                if (_errorMessage != null) ...[
                                  FadeSlideIn(
                                    duration: AppDurations.fast,
                                    child: _buildErrorBanner(),
                                  ),
                                  SizedBox(height: r.spaceSm),
                                ],
                                FadeSlideIn(
                                  duration: AppDurations.normal,
                                  delay: const Duration(milliseconds: 250),
                                  child: _buildLoginButton(),
                                ),
                              ],
                            ),
                            ),
                          ),
                        );
                        },
                      ),
                    ),
                  // Footer anclado: FUERA del scroll → nunca sube con el teclado.
                  // Se oculta cuando el teclado está activo para liberar espacio.
                  if (!keyboardVisible)
                    Padding(
                      padding: EdgeInsets.fromLTRB(r.paddingH, 0, r.paddingH, r.spaceMd),
                      child: FadeSlideIn(
                        duration: AppDurations.normal,
                        delay: const Duration(milliseconds: 350),
                        child: _buildFooter(isDark),
                      ),
                    ),
                ],
              ),
              // ── Sonido & Tema — esquina superior derecha ─────────────
              Positioned(
                top: 8,
                right: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: SoundManager.soundEnabledNotifier,
                      builder: (context, soundOn, _) => CupertinoButton(
                        padding: EdgeInsets.all(context.r.spaceSm),
                        onPressed: () => SoundManager.toggle(),
                        child: Icon(
                          soundOn
                              ? CupertinoIcons.speaker_2_fill
                              : CupertinoIcons.speaker_slash_fill,
                          size: context.r.iconMd,
                          color: AppColors.textSecondaryC(isDark),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.all(context.r.spaceSm),
                      onPressed: () => ThemeManager.toggleTheme(),
                      child: Icon(
                        isDark
                            ? CupertinoIcons.sun_max_fill
                            : CupertinoIcons.moon_fill,
                        size: context.r.iconMd,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              // ── FAB de soporte — oculto cuando el teclado está activo ──
              if (!keyboardVisible)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FadeSlideIn(
                    duration: AppDurations.normal,
                    delay: const Duration(milliseconds: 450),
                    child: _buildSupportFab(isDark),
                  ),
                ),
            ],
          ),
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
          focusNode: _usernameFocus,
          textCapitalization: TextCapitalization.characters,
          // TextInputFormatter es seguro en todos los Android —
          // evita el setState reentrante que crashea en dispositivos viejos.
          inputFormatters: [_UpperCaseFormatter()],
        ),
        SizedBox(height: r.spaceMd),
        _buildModernInputField(
          label: 'Contraseña',
          controller: _passwordController,
          placeholder: 'Codigo o Contraseña',
          icon: CupertinoIcons.lock_fill,
          obscureText: _obscurePassword,
          isDark: isDark,
          focusNode: _passwordFocus,
          isLast: true,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
              size: context.r.iconSm,
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
    FocusNode? focusNode,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final r = context.r;
    final texts = context.texts;
    // GestureDetector.opaque amplía el área de toque al container completo
    // (label + padding + field), evitando que en Android antiguo el teclado
    // no abra por pegar fuera del área mínima del CupertinoTextField.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => focusNode?.requestFocus(),
      child: Container(
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
                  focusNode: focusNode,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  inputFormatters: inputFormatters,
                  padding: EdgeInsets.zero,
                  decoration: null,
                  scrollPadding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
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
    ), // Container
    ); // GestureDetector
  }

  Widget _buildErrorBanner() {
    final r = context.r;


    final bool isNetwork = _errorType == AuthErrorType.network;
    final bool isDisabled = _errorType == AuthErrorType.disabled;
    final bool isWrongPwd = _errorType == AuthErrorType.wrongPassword;
    final bool isServer = _errorType == AuthErrorType.server;

    final IconData icon;
    final Color bannerColor;
    final Color borderColor;
    final String? title;

    if (isNetwork) {
      icon = CupertinoIcons.wifi_slash;
      bannerColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFF97316);
      title = 'Sin conexión';
    } else if (isDisabled) {
      icon = CupertinoIcons.lock_slash_fill;
      bannerColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFF97316);
      title = 'Cuenta inactiva';
    } else if (isWrongPwd) {
      icon = CupertinoIcons.lock_fill;
      bannerColor = AppColors.errorLight;
      borderColor = AppColors.error;
      title = 'Credenciales incorrectas';
    } else if (isServer) {
      icon = CupertinoIcons.exclamationmark_circle_fill;
      bannerColor = const Color(0xFFFFF7ED);
      borderColor = const Color(0xFFF97316);
      title = 'Servidor no disponible';
    } else {
      icon = CupertinoIcons.exclamationmark_triangle_fill;
      bannerColor = AppColors.errorLight;
      borderColor = AppColors.error;
      title = null;
    }

    final iconColor = (isNetwork || isDisabled || isServer)
        ? const Color(0xFFF97316)
        : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(r.radiusMd),
        border: Border.all(color: borderColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: iconColor, size: r.iconSm),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: context.texts.bodyMedium.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (title != null) const SizedBox(height: 2),
                Text(
                  _errorMessage!,
                  style: context.texts.bodyMedium.copyWith(
                    color: iconColor.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Text(
          'Dirección Nacional de Sistemas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0284C7),
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.r.spaceXs),
        Text(
          'COSSMIL',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0284C7),
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.r.spaceXs),
        Text(
          '2026',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : const Color(0xFF0284C7).withValues(alpha: 0.8),
            letterSpacing: 2.0,
          ),
          textAlign: TextAlign.center,
        ),
        if (_appVersion.isNotEmpty) ...[
          SizedBox(height: context.r.spaceXs),
          Text(
            'v$_appVersion',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.75 : 0.9),
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildSupportFab(bool isDark) {
    return Tooltip(
      message: 'Soporte: 71527970',
      child: GestureDetector(
        onTap: () => _showSupportSheet('71527970'),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF25D366),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF25D366).withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  void _showSupportSheet(String number) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Soporte COSSMIL'),
        message: Text(
          number,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse('https://wa.me/591$number'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_rounded, size: 20, color: Color(0xFF25D366)),
                SizedBox(width: 8),
                Text('Abrir en WhatsApp'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Número copiado'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copiar número'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: context.r.buttonHeight,
      child: OptimizedPressButton(
        onTap: _isLoading ? null : _onLoginPressed,
        scaleDown: 0.95,
        child: Container(
          decoration: BoxDecoration(
            color: _isLoading
                ? AppColors.textSecondary
                : const Color(0xFF16A34A),
            borderRadius: BorderRadius.circular(context.r.buttonRadius),
            border: Border.all(
              color: _isLoading
                  ? Colors.transparent
                  : const Color(0xFF15803D).withValues(alpha: 0.6),
              width: 0.8,
            ),
            boxShadow: _isLoading
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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

/// Convierte el texto a mayúsculas de forma segura en todos los Android.
/// Usa el API oficial de TextInputFormatter — evita el setState reentrante
/// que causaba crashes en dispositivos con Android < 8 al abrir el teclado.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return newValue.copyWith(
      text: upper,
      selection: newValue.selection.copyWith(
        baseOffset: newValue.selection.baseOffset.clamp(0, upper.length),
        extentOffset: newValue.selection.extentOffset.clamp(0, upper.length),
      ),
    );
  }
}
