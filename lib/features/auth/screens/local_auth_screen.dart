import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/session_restore_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/session/user_session.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/data/app_session_cache.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/cossmil_loader.dart';
import '../../../core/widgets/custom_numpad.dart';

class LocalAuthScreen extends StatefulWidget {
  /// true  → fue pusheado por TabShell al volver al primer plano.
  ///         Al desbloquear, hace pop() de vuelta al TabShell.
  /// false → fue cargado como ruta nombrada desde SplashScreen (inicio de app).
  ///         Al desbloquear, hace pushReplacement a '/home'.
  final bool isOverlay;

  const LocalAuthScreen({super.key, this.isOverlay = false});

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen>
    with SingleTickerProviderStateMixin {
  String _currentPinInput = '';
  String? _errorMessage;
  bool _isBiometricEnabled = false;
  bool _isVerifying = false;
  bool _isLoadingHome = false;

  // true mientras se carga; evita flash del keypad antes de saber si hay PIN.
  bool _hasPin = true;
  // true cuando biometría falla/cancela en modo sin-PIN → mostrar botón de login.
  bool _biometricFailed = false;

  // Nombre del usuario real desde SecurityService
  String _displayName = '';
  // Foto real recuperada en la sesión
  String _photoBase64 = '';

  // Cooldown
  Duration? _cooldownRemaining;
  Timer? _cooldownTimer;

  // Animación de shake cuando el PIN es incorrecto.
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    _init();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Carga en paralelo: nombre, biometría, cooldown y si hay PIN configurado.
    final results = await Future.wait([
      SecurityService.getDisplayName(),
      SecurityService.isBiometricsEnabled(),
      SecurityService.cooldownRemaining(),
      SecurityService.hasPin(),
    ]);

    if (!mounted) return;

    final name       = results[0] as String?;
    final bioEnabled = results[1] as bool;
    final cooldown   = results[2] as Duration?;
    final hasPinRes  = results[3] as bool;

    setState(() {
      _displayName       = name ?? '';
      _isBiometricEnabled = bioEnabled;
      _cooldownRemaining = cooldown;
      _photoBase64       = UserSession.currentUser.photoBase64;
      _hasPin            = hasPinRes;
    });

    if (cooldown != null) {
      _startCooldownTimer();
    } else if (bioEnabled) {
      // Si hay biometría configurada, dispararla primero siempre.
      // Si falla/cancela y hay PIN, el teclado queda visible como fallback.
      // Si falla/cancela y no hay PIN, aparece el botón de login con contraseña.
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _tryBiometrics();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = await SecurityService.cooldownRemaining();
      if (!mounted) return;
      setState(() => _cooldownRemaining = remaining);
      if (remaining == null) {
        timer.cancel();
        _cooldownTimer = null;
        setState(() => _errorMessage = null);
      }
    });
  }

  bool get _isBlocked => _cooldownRemaining != null;

  bool _biometricInProgress = false;

  Future<void> _tryBiometrics() async {
    if (_biometricInProgress) return;
    _biometricInProgress = true;
    if (mounted) setState(() => _biometricFailed = false);
    try {
      final authenticated = await SecurityService.authenticateWithBiometrics();
      if (authenticated && mounted) {
        _onSuccess();
      } else if (!_hasPin && mounted) {
        // Sin PIN: mostrar botón de fallback a login con contraseña.
        setState(() => _biometricFailed = true);
      }
    } finally {
      _biometricInProgress = false;
    }
  }

  void _onNumberPressed(int number) {
    if (_isVerifying || _isBlocked || _currentPinInput.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _currentPinInput += number.toString();
      _errorMessage = null;
    });
    if (_currentPinInput.length == 4) _verifyPin();
  }

  void _onDeletePressed() {
    if (_isBlocked) return;
    if (_currentPinInput.isNotEmpty) {
      setState(() {
        _currentPinInput =
            _currentPinInput.substring(0, _currentPinInput.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);

    final isValid = await SecurityService.verifyPin(_currentPinInput);

    if (!mounted) return;

    if (isValid) {
      await SecurityService.resetFailedAttempts();
      if (!mounted) return;
      _onSuccess();
    } else {
      final attempts = await SecurityService.recordFailedAttempt();
      if (!mounted) return;
      final cooldown = await SecurityService.cooldownRemaining();
      if (!mounted) return;

      await _shakeCtrl.forward(from: 0);
      HapticFeedback.vibrate();

      setState(() {
        _isVerifying = false;
        _currentPinInput = '';
        _cooldownRemaining = cooldown;
        if (cooldown != null) {
          _errorMessage = null; // El widget de cooldown lo muestra
          _startCooldownTimer();
        } else {
          final remaining = SecurityService.maxPinAttempts - attempts;
          _errorMessage = remaining <= 0
              ? 'Demasiados intentos fallidos'
              : 'PIN incorrecto · ${remaining == 1 ? "último intento" : "$remaining intentos restantes"}';
        }
      });
    }
  }

  /// Re-autentica silenciosamente con el servidor usando las credenciales
  /// almacenadas. Retorna true si el login remoto fue exitoso.
  /// En caso de fallo (sin red, credenciales no guardadas, etc.) retorna false
  /// pero NO bloquea el flujo: la sesión en memoria y el token existente
  /// actúan como fallback hasta que el usuario recupere conectividad.
  Future<bool> _silentRelogin() async {
    try {
      final creds = await SessionRestoreService.loadCredentials();
      if (creds == null) return false;
      final result = await AuthService().login(
        username: creds.username,
        password: creds.password,
      );
      return result is AuthSuccess;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onSuccess() async {
    if (widget.isOverlay) {
      // Overlay: mostrar loading, restaurar sesión completa y volver.
      // Esto garantiza que el token y los datos del usuario estén frescos
      // antes de que el TabShell vuelva a ser visible.
      setState(() => _isLoadingHome = true);
      await _silentRelogin();
      if (!mounted) return;
      try {
        await SessionRestoreService.restoreUserSession();
      } catch (_) {
        // Si falla la restauración, el token existente actúa como fallback.
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    // Primera apertura (ruta nombrada desde SplashScreen).
    setState(() => _isLoadingHome = true);

    // Re-autenticar con el servidor; si falla (sin red) se usa el token
    // existente (puede estar próximo a expirar pero el ApiClient maneja 401).
    await _silentRelogin();

    if (!mounted) return;

    try {
      await SessionRestoreService.restoreUserSession();
      if (!mounted) return;
      await ProgramacionService().verificarVersion();
    } catch (_) {
      // Si falla la verificación, navegar igual — el backend puede no estar disponible.
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/loading-data');
  }

  Future<void> _onLogoutPressed() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text(
          '¿Seguro que deseas cerrar sesión? Se borrará tu PIN y configuración de huella.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cerrar Sesión'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _cooldownTimer?.cancel();
      // Cancelar TODAS las notificaciones antes de limpiar datos
      await NotificationService.cancelAllReminders();
      // wipeAll borra tokens + PIN + sesión + todo el secure storage en un paso
      await TokenStorage.wipeAll();
      UserSession.clear();
      AppSessionCache.clear();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushReplacementNamed('/login');
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    // ── Estado de carga al navegar a home ──────────────────────────────────
    if (_isLoadingHome) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedGradientBackground(
          isDark: isDark,
          child: const Center(
            child: CossmilLoadingScreen(label: 'Iniciando sesión...'),
          ),
        ),
      );
    }

    // ── Sin PIN: pantalla de solo biometría ─────────────────────────────────
    if (!_hasPin) return _buildBiometricOnlyScreen(isDark, r);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        isDark: isDark,
        child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Header ──────────────────────────────────────────────
            FadeSlideIn(
              child: Column(
                children: [
                  _buildAvatar(isDark),
                  SizedBox(height: context.r.spaceLg),
                  Text(
                    _displayName.isNotEmpty
                        ? 'Bienvenido de vuelta'
                        : 'Desbloquea tu app',
                    style: context.texts.bodyMedium.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                  if (_displayName.isNotEmpty) ...[
                    SizedBox(height: context.r.spaceXs),
                    Text(
                      _displayName,
                      style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.accentForTheme(isDark) : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: context.r.spaceLg),
                  Text(
                    _isBlocked
                        ? 'Ingreso temporalmente bloqueado'
                        : 'Ingresa tu PIN de seguridad',
                    style: context.texts.bodyMedium.copyWith(
                      color: _isBlocked
                          ? AppColors.warning
                          : AppColors.textSecondaryC(isDark),
                      fontWeight: _isBlocked ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.r.spaceXxl),

            // ── Indicadores de PIN ──────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final offset =
                    _shakeCtrl.isAnimating ? _shakeOffset(_shakeAnim.value) : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: _buildPinIndicators(isDark, r),
            ),

            SizedBox(height: context.r.spaceMd),

            // ── Mensaje de error o cooldown ─────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isBlocked
                  ? _buildCooldownBadge()
                  : (_errorMessage != null
                      ? Padding(
                          key: ValueKey(_errorMessage),
                          padding: EdgeInsets.symmetric(horizontal: r.pinKeypadPadding),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: context.texts.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), height: 20)),
            ),

            const Spacer(),

            // ── Teclado numérico ────────────────────────────────────
            _buildKeypad(isDark, r),

            // ── Opción biométrica secundaria ─────────────────────────
            // Solo aparece cuando hay PIN + biometría configurados y
            // el usuario no está en cooldown. Es un enlace discreto,
            // no un botón prominente, para que el PIN siga siendo el
            // método principal de desbloqueo.
            if (_hasPin && _isBiometricEnabled && !_isBlocked)
              _buildBiometricLink(isDark),

            SizedBox(height: r.spaceLg),

            // ── Footer Actions ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.pinKeypadPadding),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      onPressed: _onExitApp,
                      child: Text(
                        'Salir',
                        style: context.texts.bodyMedium.copyWith(
                          color: AppColors.textSecondaryC(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: AppColors.dividerC(isDark).withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: CupertinoButton(
                      onPressed: _onLogoutPressed,
                      child: Text(
                        'Cerrar sesión',
                        style: context.texts.bodyMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: context.r.spaceMd),
          ],
        ),
      ),
      ),
    );
  }

  // ─── Pantalla de solo biometría (sin PIN configurado) ─────────────────────

  Widget _buildBiometricOnlyScreen(bool isDark, AppResponsive r) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              FadeSlideIn(
                child: Column(
                  children: [
                    _buildAvatar(isDark),
                    SizedBox(height: r.spaceLg),
                    Text(
                      _displayName.isNotEmpty
                          ? 'Bienvenido de vuelta'
                          : 'Autenticación requerida',
                      style: context.texts.bodyMedium.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    if (_displayName.isNotEmpty) ...[
                      SizedBox(height: r.spaceXs),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                        child: Text(
                          _displayName,
                          style: context.texts.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.accentForTheme(isDark) : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              // Botón biométrico central
              OptimizedPressButton(
                onTap: _biometricInProgress ? null : _tryBiometrics,
                child: Container(
                  width: r.pinKeySize * 1.8,
                  height: r.pinKeySize * 1.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: r.pinKeySize * 0.9,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: r.spaceMd),
              Text(
                'Toca para autenticarte',
                style: context.texts.bodySmall.copyWith(
                  color: AppColors.textTertiaryC(isDark),
                ),
              ),
              // Fallback: aparece cuando biometría falla o el usuario cancela
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _biometricFailed
                    ? Padding(
                        key: const ValueKey('fallback'),
                        padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                        child: Column(
                          children: [
                            SizedBox(height: r.spaceLg),
                            Text(
                              'No se pudo verificar tu identidad.\nPuedes intentarlo de nuevo o ingresar con tus credenciales.',
                              textAlign: TextAlign.center,
                              style: context.texts.bodySmall.copyWith(
                                color: AppColors.textSecondaryC(isDark),
                                height: 1.4,
                              ),
                            ),
                            CupertinoButton(
                              onPressed: () =>
                                  Navigator.pushReplacementNamed(context, '/login'),
                              child: Text(
                                'Iniciar sesión con contraseña',
                                style: context.texts.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty')),
              ),
              const Spacer(),
              CupertinoButton(
                onPressed: _onExitApp,
                child: Text(
                  'Salir',
                  style: context.texts.bodyMedium.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: r.spaceMd),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCooldownBadge() {
    final secs = _cooldownRemaining?.inSeconds ?? 0;
    final r = context.r;
    return Container(
      key: const ValueKey('cooldown'),
      margin: EdgeInsets.symmetric(horizontal: r.pinKeypadPadding),
      padding: EdgeInsets.symmetric(horizontal: r.chipPaddingH, vertical: r.chipPaddingV * 1.5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.timer, size: r.iconSm, color: AppColors.warning),
          SizedBox(width: context.r.spaceSm),
          Text(
            'Demasiados intentos. Intenta en ${secs}s',
            style: context.texts.bodySmall.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Efecto de vibración horizontal para shake.
  double _shakeOffset(double t) {
    const amp = 12.0;
    return amp * (0.5 - (t * 6).remainder(1.0)).abs() * (1 - t);
  }

  Widget _buildAvatar(bool isDark) {
    final r = context.r;
    final avatarSize = r.avatarLg;
    // Prioridad: foto real > iniciales > logo COSSMIL
    Widget avatarChild;

    if (_photoBase64.isNotEmpty) {
      // Foto real del usuario
      avatarChild = ClipOval(
        child: Image.memory(
          base64Decode(_photoBase64),
          fit: BoxFit.cover,
          width: avatarSize,
          height: avatarSize,
          errorBuilder: (_, __, ___) => _buildInitialsOrLogo(isDark, avatarSize),
        ),
      );
    } else {
      avatarChild = _buildInitialsOrLogo(isDark, avatarSize);
    }

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.darkElevated : AppColors.white,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 2.5,
        ),
        boxShadow: isDark ? [] : AppShadows.soft,
      ),
      child: ClipOval(child: avatarChild),
    );
  }

  Widget _buildInitialsOrLogo(bool isDark, double size) {
    final trimmed = _displayName.trim();
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(RegExp(r'\s+'));
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();
      return Container(
        width: size,
        height: size,
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.2)
            : AppColors.primaryLight,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    // Fallback: logo COSSMIL
    return Padding(
      padding: EdgeInsets.all(size * 0.15),
      child: Image.asset(
        'assets/images/cossmil_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          CupertinoIcons.shield_fill,
          size: size * 0.4,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildPinIndicators(bool isDark, AppResponsive r) {
    final dotSize = r.pinDotSize;
    final dotMargin = r.pinDotMargin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < _currentPinInput.length;
        final isError = _errorMessage != null;
        final activeColor = isDark ? Colors.white : const Color(0xFF0284C7);
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(horizontal: dotMargin),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError && isActive
                ? AppColors.error
                : isActive
                    ? activeColor
                    : (isDark ? Colors.white12 : const Color(0xFFBAE6FD)),
            border: isActive
                ? Border.all(
                    color: isError ? AppColors.error : activeColor,
                    width: 2,
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(bool isDark, AppResponsive r) {
    return CustomNumpad(
      isDark: isDark,
      disabled: _isBlocked,
      onNumberPressed: _onNumberPressed,
      onDelete: _onDeletePressed,
      leftBottomWidget: _buildBiometricKey(isDark, r),
    );
  }

  /// Enlace discreto "Usar huella / rostro" para usuarios que tienen
  /// tanto PIN como biometría habilitada. No reemplaza al PIN como método
  /// primario — el usuario debe elegirlo activamente.
  Widget _buildBiometricLink(bool isDark) {
    return CupertinoButton(
      padding: EdgeInsets.symmetric(vertical: context.r.spaceSm),
      onPressed: _biometricInProgress ? null : _tryBiometrics,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fingerprint,
            size: context.r.iconSm,
            color: AppColors.primary.withValues(alpha: 0.65),
          ),
          SizedBox(width: context.r.spaceXs),
          Text(
            'Usar huella o rostro',
            style: context.texts.bodySmall.copyWith(
              color: AppColors.primary.withValues(alpha: 0.65),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricKey(bool isDark, AppResponsive r) {
    final keySize = r.pinKeySize;
    // Ocultar del teclado numérico cuando hay PIN configurado.
    // En ese caso la biometría se ofrece como enlace secundario bajo el teclado,
    // no como botón integrado que permite saltarse los 4 dígitos.
    if (!_isBiometricEnabled || _isBlocked || _hasPin) {
      return SizedBox(width: keySize, height: keySize);
    }

    return SizedBox(
      width: keySize,
      height: keySize,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _tryBiometrics,
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary.withValues(alpha: 0.2),
          highlightColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.fingerprint,
            size: keySize * 0.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _onExitApp() {
    SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }
}
