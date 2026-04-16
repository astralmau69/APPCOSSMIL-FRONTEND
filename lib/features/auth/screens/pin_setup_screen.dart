import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/security_service.dart';
import '../../../core/widgets/custom_numpad.dart';

/// Pantalla de creación/cambio de PIN de 4 dígitos.
///
/// Si [requireCurrentPin] es true (cambio de PIN), el flujo añade una fase 0
/// donde se verifica el PIN actual antes de permitir crear uno nuevo.
///
/// Flujo con [requireCurrentPin] = true:
///   [Verificar PIN actual] → [Nuevo PIN] → [Confirmar nuevo PIN] → guardado
/// Flujo con [requireCurrentPin] = false (primer setup):
///   [Nuevo PIN] → [Confirmar nuevo PIN] → guardado
///
/// Retorna [true] al pop si el PIN fue guardado exitosamente.
class PinSetupScreen extends StatefulWidget {
  /// Si es true, la primera fase pide el PIN actual antes de crear uno nuevo.
  final bool requireCurrentPin;

  const PinSetupScreen({super.key, this.requireCurrentPin = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

// Fases del flujo
enum _PinPhase { verifyCurrentPin, createNewPin, confirmNewPin }

class _PinSetupScreenState extends State<PinSetupScreen>
    with SingleTickerProviderStateMixin {
  String _currentPinInput = ''; // PIN actual (si requireCurrentPin)
  String _newPin = '';
  String _confirmPin = '';
  String? _errorMessage;
  bool _saving = false;

  late _PinPhase _phase;

  // Shake para PIN actual incorrecto
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _phase = widget.requireCurrentPin
        ? _PinPhase.verifyCurrentPin
        : _PinPhase.createNewPin;

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ─── Input activo según la fase ────────────────────────────────────────────

  String get _activeInput {
    switch (_phase) {
      case _PinPhase.verifyCurrentPin: return _currentPinInput;
      case _PinPhase.createNewPin:     return _newPin;
      case _PinPhase.confirmNewPin:    return _confirmPin;
    }
  }

  void _setActiveInput(String v) {
    switch (_phase) {
      case _PinPhase.verifyCurrentPin:
        setState(() => _currentPinInput = v);
        break;
      case _PinPhase.createNewPin:
        setState(() => _newPin = v);
        break;
      case _PinPhase.confirmNewPin:
        setState(() => _confirmPin = v);
        break;
    }
  }

  // ─── Acciones ──────────────────────────────────────────────────────────────

  void _onNumberPressed(int number) {
    if (_saving || _activeInput.length >= 4) return;
    setState(() => _errorMessage = null);

    final next = _activeInput + number.toString();
    _setActiveInput(next);

    if (next.length == 4) {
      Future.microtask(_handleFullInput);
    }
  }

  void _onDeletePressed() {
    if (_saving) return;
    setState(() => _errorMessage = null);
    if (_activeInput.isNotEmpty) {
      _setActiveInput(_activeInput.substring(0, _activeInput.length - 1));
    } else if (_phase == _PinPhase.confirmNewPin) {
      _goBackToCreatePin();
    }
  }

  void _goBackToCreatePin() {
    setState(() {
      _phase = _PinPhase.createNewPin;
      _newPin = '';
      _confirmPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _handleFullInput() async {
    switch (_phase) {
      case _PinPhase.verifyCurrentPin:
        await _verifyCurrentPin();
        break;
      case _PinPhase.createNewPin:
        // Avanzar a confirmación
        setState(() => _phase = _PinPhase.confirmNewPin);
        break;
      case _PinPhase.confirmNewPin:
        await _verifyAndSave();
        break;
    }
  }

  Future<void> _verifyCurrentPin() async {
    setState(() => _saving = true);
    final isValid = await SecurityService.verifyPin(_currentPinInput);
    if (!mounted) return;

    if (isValid) {
      setState(() {
        _saving = false;
        _phase = _PinPhase.createNewPin;
        _currentPinInput = '';
        _errorMessage = null;
      });
    } else {
      await _shakeCtrl.forward(from: 0);
      HapticFeedback.vibrate();
      setState(() {
        _saving = false;
        _currentPinInput = '';
        _errorMessage = 'PIN actual incorrecto. Inténtalo de nuevo.';
      });
    }
  }

  Future<void> _verifyAndSave() async {
    if (_newPin != _confirmPin) {
      HapticFeedback.vibrate();
      setState(() {
        _confirmPin = '';
        _errorMessage = 'Los PIN no coinciden. Intenta de nuevo.';
      });
      return;
    }

    setState(() => _saving = true);
    await SecurityService.savePin(_newPin);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return PopScope(
      canPop: _phase != _PinPhase.confirmNewPin,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _PinPhase.confirmNewPin) {
          _goBackToCreatePin();
        }
      },
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        middle: Text(_appBarTitle),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: r.spaceXl),

            // ── Header animado entre fases ──────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _buildPhaseHeader(isDark, r),
            ),

            SizedBox(height: r.spaceXxl),

            // ── Indicadores ─────────────────────────────────────
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                final offset = _shakeCtrl.isAnimating
                    ? _shakeOffset(_shakeAnim.value)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: _buildPinIndicators(isDark, r),
            ),

            SizedBox(height: r.spaceMd),

            // ── Error ────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _errorMessage != null
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
                  : const SizedBox(key: ValueKey('none'), height: 20),
            ),

            const Spacer(),

            // ── Teclado ──────────────────────────────────────────
            _buildKeypad(isDark, r),

            SizedBox(height: r.spaceLg),
          ],
        ),
      ),
      ),
    );
  }

  String get _appBarTitle {
    switch (_phase) {
      case _PinPhase.verifyCurrentPin: return 'Verificar PIN actual';
      case _PinPhase.createNewPin:     return 'Crear nuevo PIN';
      case _PinPhase.confirmNewPin:    return 'Confirmar PIN';
    }
  }

  Widget _buildPhaseHeader(bool isDark, AppResponsive r) {
    final iconSize = r.isSmallPhone ? 48.0 : 64.0;
    switch (_phase) {
      case _PinPhase.verifyCurrentPin:
        return Column(
          key: const ValueKey('verify'),
          children: [
            Icon(
              CupertinoIcons.lock_shield_fill,
              size: iconSize,
              color: AppColors.warning,
            ),
            SizedBox(height: r.spaceLg),
            Text(
              'Confirma tu PIN actual',
              style: context.texts.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: r.spaceSm),
            Text(
              'Ingresa tu PIN actual para continuar',
              style: context.texts.bodyMedium.copyWith(
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ],
        );
      case _PinPhase.createNewPin:
        return Column(
          key: const ValueKey('create'),
          children: [
            Icon(
              CupertinoIcons.lock_shield_fill,
              size: iconSize,
              color: AppColors.primary,
            ),
            SizedBox(height: r.spaceLg),
            Text(
              widget.requireCurrentPin ? 'Crea tu nuevo PIN' : 'Crea tu PIN de acceso',
              style: context.texts.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: r.spaceSm),
            Text(
              'Ingresa 4 dígitos para proteger tu app',
              style: context.texts.bodyMedium.copyWith(
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ],
        );
      case _PinPhase.confirmNewPin:
        return Column(
          key: const ValueKey('confirm'),
          children: [
            Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: iconSize,
              color: AppColors.success,
            ),
            SizedBox(height: r.spaceLg),
            Text(
              'Confirma tu nuevo PIN',
              style: context.texts.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: r.spaceSm),
            Text(
              'Repite los 4 dígitos para confirmar',
              style: context.texts.bodyMedium.copyWith(
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ],
        );
    }
  }

  double _shakeOffset(double t) {
    const amp = 12.0;
    return amp * (0.5 - (t * 6).remainder(1.0)).abs() * (1 - t);
  }

  Color get _activeIndicatorColor {
    switch (_phase) {
      case _PinPhase.verifyCurrentPin: return AppColors.warning;
      case _PinPhase.createNewPin:     return AppColors.primary;
      case _PinPhase.confirmNewPin:    return AppColors.success;
    }
  }

  Widget _buildPinIndicators(bool isDark, AppResponsive r) {
    final currentLength = _activeInput.length;
    final dotSize = r.isSmallPhone ? 14.0 : 16.0;
    final dotMargin = r.isSmallPhone ? 8.0 : 12.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < currentLength;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: dotMargin),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? _activeIndicatorColor
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(bool isDark, AppResponsive r) {
    return CustomNumpad(
      isDark: isDark,
      disabled: _saving,
      onNumberPressed: _onNumberPressed,
      onDelete: _onDeletePressed,
    );
  }
}
