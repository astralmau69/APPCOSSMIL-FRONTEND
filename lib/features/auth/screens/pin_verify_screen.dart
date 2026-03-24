import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/services/security_service.dart';
import '../../../core/animations/optimized_animations.dart';

/// Pantalla de solo verificación de PIN (NO crea ni cambia PIN).
///
/// Retorna [true] via [Navigator.pop] si el PIN fue verificado exitosamente.
/// Retorna [false] o null si el usuario cancela.
///
/// Uso típico:
///   final ok = await Navigator.push(context, CupertinoPageRoute(
///     builder: (_) => PinVerifyScreen(title: 'Confirma tu PIN', subtitle: '...'),
///   ));
class PinVerifyScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  const PinVerifyScreen({
    super.key,
    this.title = 'Confirma tu PIN',
    this.subtitle = 'Ingresa tu PIN actual para continuar',
  });

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen>
    with SingleTickerProviderStateMixin {
  String _pinInput = '';
  String? _errorMessage;
  bool _isVerifying = false;

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
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onNumberPressed(int number) {
    if (_isVerifying || _pinInput.length >= 4) return;
    setState(() {
      _pinInput += number.toString();
      _errorMessage = null;
    });
    if (_pinInput.length == 4) _verifyPin();
  }

  void _onDeletePressed() {
    if (_pinInput.isNotEmpty) {
      setState(() {
        _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    final isValid = await SecurityService.verifyPin(_pinInput);
    if (!mounted) return;

    if (isValid) {
      Navigator.pop(context, true);
    } else {
      await _shakeCtrl.forward(from: 0);
      HapticFeedback.vibrate();
      setState(() {
        _isVerifying = false;
        _pinInput = '';
        _errorMessage = 'PIN incorrecto. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        backgroundColor: Colors.transparent,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.primary)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Header ────────────────────────────────────────
            FadeSlideIn(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      CupertinoIcons.lock_shield_fill,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── Indicadores PIN ───────────────────────────────
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

            // ── Error ─────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _errorMessage != null
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
                  : const SizedBox(key: ValueKey('empty'), height: 20),
            ),

            const Spacer(),

            // ── Teclado ───────────────────────────────────────
            _buildKeypad(isDark),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  double _shakeOffset(double t) {
    const amp = 12.0;
    return amp * (0.5 - (t * 6).remainder(1.0)).abs() * (1 - t);
  }

  Widget _buildPinIndicators(bool isDark) {
    final isError = _errorMessage != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index < _pinInput.length;
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
          _buildRow([1, 2, 3], isDark),
          const SizedBox(height: 20),
          _buildRow([4, 5, 6], isDark),
          const SizedBox(height: 20),
          _buildRow([7, 8, 9], isDark),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 72, height: 72),
              _buildNumberKey(0, isDark),
              _buildDeleteKey(),
            ],
          ),
        ],
      ),
    );
  }

  Row _buildRow(List<int> nums, bool isDark) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: nums.map((n) => _buildNumberKey(n, isDark)).toList(),
      );

  Widget _buildNumberKey(int number, bool isDark) {
    return OptimizedPressButton(
      onTap: _isVerifying ? null : () => _onNumberPressed(number),
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
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return OptimizedPressButton(
      onTap: _onDeletePressed,
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
