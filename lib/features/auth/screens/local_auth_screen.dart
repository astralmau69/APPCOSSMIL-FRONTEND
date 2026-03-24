import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/session_restore_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/animated_gradient_background.dart';

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

  // Nombre del usuario sin depender de MockUserData
  String _displayName = '';
  // Foto base64 del usuario real
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
    // Carga en paralelo: nombre, biometría y cooldown actual
    final results = await Future.wait([
      SecurityService.getDisplayName(),
      SecurityService.isBiometricsEnabled(),
      SecurityService.cooldownRemaining(),
    ]);

    if (!mounted) return;

    final name = results[0] as String?;
    final bioEnabled = results[1] as bool;
    final cooldown = results[2] as Duration?;

    setState(() {
      _displayName = name ?? '';
      _isBiometricEnabled = bioEnabled;
      _cooldownRemaining = cooldown;
      // Foto desde MockUserData (ya restaurado por SessionRestoreService)
      _photoBase64 = MockUserData.user.photoBase64;
    });

    if (cooldown != null) {
      _startCooldownTimer();
    } else if (bioEnabled) {
      // Pequeño delay para que la pantalla termine de montar antes del prompt.
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

  Future<void> _tryBiometrics() async {
    final authenticated = await SecurityService.authenticateWithBiometrics();
    if (authenticated && mounted) _onSuccess();
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

  void _onSuccess() {
    if (widget.isOverlay) {
      // Solo cerramos el overlay; el TabShell sigue vivo debajo.
      Navigator.of(context).pop();
    } else {
      // Primera apertura desde Splash: navegar al shell principal.
      Navigator.pushReplacementNamed(context, '/home');
    }
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
      await TokenStorage.deleteToken();
      await SecurityService.clearSecurityData();
      await SessionRestoreService.clearUserSession();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true)
          .pushReplacementNamed('/login');
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  const SizedBox(height: 20),
                  Text(
                    _displayName.isNotEmpty
                        ? 'Bienvenido de vuelta'
                        : 'Desbloquea tu app',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_displayName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _displayName,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.razer : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    _isBlocked
                        ? 'Ingreso temporalmente bloqueado'
                        : 'Ingresa tu PIN de seguridad',
                    style: AppTypography.bodyMedium.copyWith(
                      color: _isBlocked
                          ? AppColors.warning
                          : AppColors.textSecondary,
                      fontWeight: _isBlocked ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

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
              child: _buildPinIndicators(isDark),
            ),

            const SizedBox(height: 16),

            // ── Mensaje de error o cooldown ─────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isBlocked
                  ? _buildCooldownBadge()
                  : (_errorMessage != null
                      ? Padding(
                          key: ValueKey(_errorMessage),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), height: 20)),
            ),

            const Spacer(),

            // ── Teclado numérico ────────────────────────────────────
            _buildKeypad(isDark),

            const SizedBox(height: 24),

            // ── Cerrar sesión ────────────────────────────────────────
            CupertinoButton(
              onPressed: _onLogoutPressed,
              child: Text(
                'Cerrar sesión',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCooldownBadge() {
    final secs = _cooldownRemaining?.inSeconds ?? 0;
    return Container(
      key: const ValueKey('cooldown'),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.timer, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'Demasiados intentos. Intenta en ${secs}s',
            style: AppTypography.bodySmall.copyWith(
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
    // Prioridad: foto real > iniciales > logo COSSMIL
    Widget avatarChild;

    if (_photoBase64.isNotEmpty) {
      // Foto real del usuario
      avatarChild = ClipOval(
        child: Image.memory(
          base64Decode(_photoBase64),
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (_, __, ___) => _buildInitialsOrLogo(isDark),
        ),
      );
    } else {
      avatarChild = _buildInitialsOrLogo(isDark);
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF2C2C2E) : AppColors.white,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 2.5,
        ),
        boxShadow: isDark ? [] : AppShadows.soft,
      ),
      child: ClipOval(child: avatarChild),
    );
  }

  Widget _buildInitialsOrLogo(bool isDark) {
    if (_displayName.isNotEmpty) {
      // Iniciales del usuario
      final parts = _displayName.trim().split(RegExp(r'\s+'));
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : parts[0][0].toUpperCase();
      return Container(
        width: 80,
        height: 80,
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.2)
            : AppColors.primaryLight,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 28,
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
      padding: const EdgeInsets.all(12),
      child: Image.asset(
        'assets/images/cossmil_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          CupertinoIcons.shield_fill,
          size: 32,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildPinIndicators(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < _currentPinInput.length;
        final isError = _errorMessage != null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError && isActive
                ? AppColors.error
                : isActive
                    ? AppColors.primary
                    : (isDark ? Colors.white12 : Colors.grey.shade200),
            border: isActive
                ? Border.all(
                    color: isError ? AppColors.error : AppColors.primary,
                    width: 2,
                  )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _buildKeyRow([1, 2, 3], isDark),
          const SizedBox(height: 20),
          _buildKeyRow([4, 5, 6], isDark),
          const SizedBox(height: 20),
          _buildKeyRow([7, 8, 9], isDark),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBiometricKey(),
              _buildNumberKey(0, isDark),
              _buildDeleteKey(),
            ],
          ),
        ],
      ),
    );
  }

  Row _buildKeyRow(List<int> numbers, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: numbers.map((n) => _buildNumberKey(n, isDark)).toList(),
    );
  }

  Widget _buildNumberKey(int number, bool isDark) {
    final blocked = _isBlocked;
    return OptimizedPressButton(
      onTap: blocked ? null : () => _onNumberPressed(number),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: blocked
              ? (isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100)
                  .withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: AppTypography.displayMedium.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              color: blocked
                  ? AppColors.textTertiary
                  : (isDark ? AppColors.white : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricKey() {
    if (!_isBiometricEnabled || _isBlocked) {
      return const SizedBox(width: 72, height: 72);
    }

    return OptimizedPressButton(
      onTap: _tryBiometrics,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Icon(
          Icons.fingerprint,
          size: 38,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return OptimizedPressButton(
      onTap: _isBlocked ? null : _onDeletePressed,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Icon(
          CupertinoIcons.delete_left,
          size: 28,
          color:
              _isBlocked ? AppColors.textTertiary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
