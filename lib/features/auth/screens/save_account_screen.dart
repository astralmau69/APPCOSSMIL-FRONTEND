import 'package:flutter/cupertino.dart';
import '../../../core/animations/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/animated_gradient_background.dart';
import '../../../core/models/saved_account.dart';
import '../../../core/services/accounts_store.dart';
import '../../../core/services/security_service.dart';
import '../../../core/utils/pin_hasher.dart';
import '../../../core/widgets/custom_numpad.dart';

/// Pantalla para GUARDAR una cuenta en la cajita de login rápido:
/// el usuario define un PIN de 4 dígitos (lo escribe dos veces) y, si el
/// dispositivo tiene biometría, se le ofrece habilitar la huella para esa
/// cuenta. Al terminar guarda la cuenta y hace `pop(true)`.
class SaveAccountScreen extends StatefulWidget {
  final String matricula;
  final String password;
  final String displayName;
  final String photoBase64;

  const SaveAccountScreen({
    super.key,
    required this.matricula,
    required this.password,
    required this.displayName,
    this.photoBase64 = '',
  });

  @override
  State<SaveAccountScreen> createState() => _SaveAccountScreenState();
}

class _SaveAccountScreenState extends State<SaveAccountScreen> {
  String _pin = '';
  String? _firstPin; // PIN de la primera fase (a confirmar)
  String? _error;
  bool _saving = false;

  bool get _confirming => _firstPin != null;

  void _onNumber(int n) {
    if (_saving || _pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += n.toString();
      _error = null;
    });
    if (_pin.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onComplete() async {
    if (!_confirming) {
      // Primera fase: recordar y pedir confirmación.
      setState(() {
        _firstPin = _pin;
        _pin = '';
      });
      return;
    }

    // Segunda fase: confirmar.
    if (_pin != _firstPin) {
      HapticFeedback.vibrate();
      setState(() {
        _error = 'Los PIN no coinciden. Empieza de nuevo.';
        _firstPin = null;
        _pin = '';
      });
      return;
    }

    await _save(_firstPin!);
  }

  Future<void> _save(String pin) async {
    setState(() => _saving = true);

    // ¿Ofrecer huella?
    bool useBiometric = false;
    final bioStatus = await SecurityService.getDeviceBiometricStatus();
    if (mounted && bioStatus == DeviceBiometricStatus.available) {
      final label = await SecurityService.getBiometricLabel();
      if (!mounted) return;
      useBiometric =
          await showAppDialog<bool>(
            context: context,
            builder: (ctx) => CupertinoAlertDialog(
              title: Text('Activar $label'),
              content: Text(
                '¿Deseas usar $label para entrar a esta cuenta sin escribir el PIN?',
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Ahora no'),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Activar'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ) ??
          false;
    }

    final ph = PinHasher.hash(pin);
    final account = SavedAccount(
      matricula: widget.matricula,
      displayName: widget.displayName,
      photoBase64: widget.photoBase64,
      pinHash: ph.hash,
      pinSalt: ph.salt,
      biometricEnabled: useBiometric,
      lastUsedMs: DateTime.now().millisecondsSinceEpoch,
    );

    await AccountsStore.upsert(account: account, password: widget.password);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedGradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: EdgeInsets.all(r.spaceMd),
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Icon(
                CupertinoIcons.lock_shield_fill,
                size: r.iconLg * 1.4,
                color: AppColors.primary,
              ),
              SizedBox(height: r.spaceLg),
              Text(
                _confirming
                    ? 'Confirma tu PIN'
                    : 'Crea un PIN para esta cuenta',
                style: context.texts.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryC(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: r.spaceSm),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                child: Text(
                  _confirming
                      ? 'Vuelve a ingresar los 4 dígitos.'
                      : 'Lo usarás para entrar rápido a ${widget.displayName.isNotEmpty ? widget.displayName : widget.matricula}.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodyMedium.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: r.spaceXl),
              _buildDots(isDark, r),
              SizedBox(
                height: 28,
                child: _error != null
                    ? Padding(
                        padding: EdgeInsets.only(top: r.spaceSm),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: context.texts.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              CustomNumpad(
                isDark: isDark,
                disabled: _saving,
                onNumberPressed: _onNumber,
                onDelete: _onDelete,
              ),
              SizedBox(height: r.spaceLg),
              SizedBox(height: r.spaceMd),
            ],
          ),
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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: EdgeInsets.symmetric(horizontal: r.pinDotMargin),
          width: r.pinDotSize,
          height: r.pinDotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? activeColor
                : (isDark ? Colors.white12 : const Color(0xFFBAE6FD)),
          ),
        );
      }),
    );
  }
}
