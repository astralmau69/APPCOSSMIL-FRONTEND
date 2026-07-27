import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sounds.dart';
import '../../../core/theme/sound_manager.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/models/saved_account.dart';
import '../../../core/services/accounts_store.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/services/session_restore_service.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/widgets/cossmil_loader.dart';
import '../../../core/widgets/custom_numpad.dart';

/// Pantalla de desbloqueo de una cuenta guardada (login rápido multi-cuenta).
///
/// Pide el PIN de 4 dígitos de ESA cuenta (o huella si la habilitó) y, al
/// validar, hace un re-login silencioso con la contraseña guardada y navega
/// a la app. Si la contraseña guardada ya no es válida (el usuario la cambió),
/// ofrece volver al login para escribirla de nuevo.
class AccountUnlockScreen extends StatefulWidget {
  final SavedAccount account;

  const AccountUnlockScreen({super.key, required this.account});

  @override
  State<AccountUnlockScreen> createState() => _AccountUnlockScreenState();
}

class _AccountUnlockScreenState extends State<AccountUnlockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _verifying = false;
  bool _loadingHome = false;

  int _failed = 0;
  static const _maxAttempts = 5;
  Duration? _cooldown;
  Timer? _cooldownTimer;
  bool _bioInProgress = false;

  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  bool get _blocked => _cooldown != null;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    if (widget.account.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tryBiometrics();
      });
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onNumber(int n) {
    if (_verifying || _blocked || _pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += n.toString();
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onDelete() {
    if (_blocked || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final ok = AccountsStore.verifyPin(widget.account, _pin);
    if (!mounted) return;

    if (ok) {
      _failed = 0;
      await _loginAndEnter();
    } else {
      _failed++;
      SoundManager.playUi(AppSounds.error, volume: 0.5);
      await _shakeCtrl.forward(from: 0);
      HapticFeedback.vibrate();
      if (_failed >= _maxAttempts) {
        _startCooldown();
      }
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _pin = '';
        if (!_blocked) {
          final left = _maxAttempts - _failed;
          _error = left <= 0
              ? 'Demasiados intentos'
              : 'PIN incorrecto · ${left == 1 ? "último intento" : "$left intentos"}';
        } else {
          _error = null;
        }
      });
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = const Duration(seconds: 30));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining =
          (_cooldown ?? Duration.zero) - const Duration(seconds: 1);
      setState(() {
        if (remaining.inSeconds <= 0) {
          _cooldown = null;
          _failed = 0;
          t.cancel();
          _cooldownTimer = null;
        } else {
          _cooldown = remaining;
        }
      });
    });
  }

  Future<void> _tryBiometrics() async {
    if (_bioInProgress || _blocked) return;
    _bioInProgress = true;
    try {
      final result = await SecurityService.authenticateWithBiometrics(
        reason: 'Desbloquea la cuenta de ${widget.account.displayName}',
      );
      if (!mounted) return;
      if (result == BiometricAuthResult.success) {
        await _loginAndEnter();
      } else if (result == BiometricAuthResult.lockedOut) {
        setState(() => _error = 'Sensor bloqueado. Usa tu PIN.');
      }
    } finally {
      _bioInProgress = false;
    }
  }

  /// Re-login silencioso con la contraseña guardada y entrada a la app.
  Future<void> _loginAndEnter() async {
    setState(() {
      _verifying = true;
      _loadingHome = true;
    });

    final matricula = widget.account.matricula;
    final pwd = await AccountsStore.getPassword(matricula);
    if (pwd == null) {
      _showReloginNeeded(
        'No encontramos la contraseña guardada de esta cuenta.',
      );
      return;
    }

    final result = await AuthService().login(
      username: matricula,
      password: pwd,
    );
    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final token):
        // Guardar credenciales activas (para el bloqueo en-sesión) y refrescar
        // la tarjeta con nombre/foto recién obtenidos.
        await SessionRestoreService.storeCredentials(matricula, pwd);
        await AccountsStore.touch(matricula);
        await AccountsStore.updateProfile(
          matricula,
          displayName: UserSession.currentUser.displayName,
          photoBase64: UserSession.currentUser.photoBase64,
        );

        // Verificación de versión best-effort (no bloquea si falla la red).
        try {
          await ProgramacionService().verificarVersion();
        } catch (_) {}
        if (!mounted) return;

        // reqReset == false → debe cambiar contraseña primero.
        if (!token.reqReset) {
          Navigator.pushReplacementNamed(context, '/password-change');
        } else {
          Navigator.pushReplacementNamed(context, '/loading-data');
        }

      case AuthError(:final message):
        // Contraseña inválida (cambiada en otro lado) o error de red.
        await TokenStorage.deleteToken();
        _showReloginNeeded(message);
    }
  }

  void _showReloginNeeded(String message) {
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _loadingHome = false;
      _pin = '';
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    if (_loadingHome) {
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              // Volver a la lista de cuentas.
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: EdgeInsets.all(r.spaceMd),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Icon(
                    CupertinoIcons.back,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              FadeSlideIn(
                child: Column(
                  children: [
                    _buildAvatar(isDark, r),
                    SizedBox(height: r.spaceLg),
                    Text(
                      'Hola de nuevo',
                      style: context.texts.bodyMedium.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    SizedBox(height: r.spaceXs),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                      child: Text(
                        widget.account.displayName.isNotEmpty
                            ? widget.account.displayName
                            : widget.account.matricula,
                        style: context.texts.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.accentForTheme(isDark)
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: r.spaceLg),
                    Text(
                      _blocked
                          ? 'Bloqueado temporalmente'
                          : 'Ingresa tu PIN de 4 dígitos',
                      style: context.texts.bodyMedium.copyWith(
                        color: _blocked
                            ? AppColors.warning
                            : AppColors.textSecondaryC(isDark),
                        fontWeight: _blocked ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spaceXl),
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  final off = _shakeCtrl.isAnimating
                      ? _shakeOffset(_shakeAnim.value)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(off, 0),
                    child: child,
                  );
                },
                child: _buildDots(isDark, r),
              ),
              SizedBox(height: r.spaceMd),
              SizedBox(
                height: 22,
                child: _blocked
                    ? Text(
                        'Intenta en ${_cooldown!.inSeconds}s',
                        style: context.texts.bodySmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : (_error != null
                          ? Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.paddingH,
                              ),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: context.texts.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null),
              ),
              const Spacer(),
              CustomNumpad(
                isDark: isDark,
                disabled: _blocked || _verifying,
                onNumberPressed: _onNumber,
                onDelete: _onDelete,
                leftBottomWidget: widget.account.biometricEnabled && !_blocked
                    ? _buildBiometricKey(r)
                    : null,
              ),
              SizedBox(height: r.spaceLg),
              SizedBox(height: r.spaceMd),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricKey(AppResponsive r) {
    final keySize = r.pinKeySize;
    return OptimizedPressButton(
      onTap: _bioInProgress ? null : _tryBiometrics,
      scaleDown: 0.92,
      haptic: true,
      child: Container(
        width: keySize,
        height: keySize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.1),
        ),
        child: Icon(
          Icons.fingerprint,
          size: keySize * 0.5,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildDots(bool isDark, AppResponsive r) {
    final activeColor = isDark ? Colors.white : const Color(0xFF0284C7);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i < _pin.length;
        final isError = _error != null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(horizontal: r.pinDotMargin),
          width: r.pinDotSize,
          height: r.pinDotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isError && active
                ? AppColors.error
                : active
                ? activeColor
                : (isDark ? Colors.white12 : const Color(0xFFBAE6FD)),
          ),
        );
      }),
    );
  }

  Widget _buildAvatar(bool isDark, AppResponsive r) {
    final size = r.avatarLg;
    Widget child;
    if (widget.account.photoBase64.isNotEmpty) {
      try {
        child = Image.memory(
          base64Decode(widget.account.photoBase64),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => _initials(size, isDark),
        );
      } catch (_) {
        child = _initials(size, isDark);
      }
    } else {
      child = _initials(size, isDark);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? AppColors.darkElevated : AppColors.white,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 2.5,
        ),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _initials(double size, bool isDark) {
    final name = widget.account.displayName.trim();
    final src = name.isNotEmpty ? name : widget.account.matricula;
    final parts = src.split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (src.isNotEmpty ? src[0].toUpperCase() : '?');
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
          ),
        ),
      ),
    );
  }

  double _shakeOffset(double t) {
    const amp = 12.0;
    return amp * (0.5 - (t * 6).remainder(1.0)).abs() * (1 - t);
  }
}
