import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/services/security_service.dart';
import '../../../core/animations/optimized_animations.dart';

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
      // Retroceder a crear
      setState(() {
        _phase = _PinPhase.createNewPin;
        _newPin = _newPin.isNotEmpty
            ? _newPin.substring(0, _newPin.length - 1)
            : '';
      });
    }
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        middle: Text(_appBarTitle),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

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
              child: _buildPhaseHeader(),
            ),

            const SizedBox(height: 48),

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
              child: _buildPinIndicators(isDark),
            ),

            const SizedBox(height: 16),

            // ── Error ────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _errorMessage != null
                  ? Padding(
                      key: ValueKey(_errorMessage),
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('none'), height: 20),
            ),

            const Spacer(),

            // ── Teclado ──────────────────────────────────────────
            _buildKeypad(isDark),

            const SizedBox(height: 32),
          ],
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

  Widget _buildPhaseHeader() {
    switch (_phase) {
      case _PinPhase.verifyCurrentPin:
        return Column(
          key: const ValueKey('verify'),
          children: [
            const Icon(
              CupertinoIcons.lock_shield_fill,
              size: 64,
              color: AppColors.warning,
            ),
            const SizedBox(height: 24),
            Text(
              'Confirma tu PIN actual',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa tu PIN actual para continuar',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      case _PinPhase.createNewPin:
        return Column(
          key: const ValueKey('create'),
          children: [
            const Icon(
              CupertinoIcons.lock_shield_fill,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              widget.requireCurrentPin ? 'Crea tu nuevo PIN' : 'Crea tu PIN de acceso',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa 4 dígitos para proteger tu app',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      case _PinPhase.confirmNewPin:
        return Column(
          key: const ValueKey('confirm'),
          children: [
            const Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: 64,
              color: AppColors.success,
            ),
            const SizedBox(height: 24),
            Text(
              'Confirma tu nuevo PIN',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Repite los 4 dígitos para confirmar',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
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

  Widget _buildPinIndicators(bool isDark) {
    final currentLength = _activeInput.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < currentLength;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
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

  Widget _buildKeypad(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          _buildRow([1, 2, 3], isDark),
          const SizedBox(height: 24),
          _buildRow([4, 5, 6], isDark),
          const SizedBox(height: 24),
          _buildRow([7, 8, 9], isDark),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 72),
              _buildKey(0, isDark),
              _buildDeleteKey(),
            ],
          ),
        ],
      ),
    );
  }

  Row _buildRow(List<int> nums, bool isDark) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: nums.map((n) => _buildKey(n, isDark)).toList(),
      );

  Widget _buildKey(int number, bool isDark) {
    return OptimizedPressButton(
      onTap: _saving ? null : () => _onNumberPressed(number),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: AppTypography.displayMedium.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return OptimizedPressButton(
      onTap: _saving ? null : _onDeletePressed,
      child: const SizedBox(
        width: 72,
        height: 72,
        child: Icon(
          CupertinoIcons.delete_left,
          size: 28,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
