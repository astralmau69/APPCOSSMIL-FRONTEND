import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/services/security_service.dart';
import '../../../core/animations/optimized_animations.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onNumberPressed(int number) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += number.toString();
          if (_pin.length == 4) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += number.toString();
          if (_confirmPin.length == 4) {
            _verifyAndSave();
          }
        }
      }
      _errorMessage = null;
    });
  }

  void _onDeletePressed() {
    setState(() {
      if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      await SecurityService.savePin(_pin);
      if (!mounted) return;
      
      // Mostrar éxito y preguntar por biometría
      final canUseBiometrics = await SecurityService.canCheckBiometrics();
      if (canUseBiometrics && mounted) {
        final useBio = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Biometría'),
            content: const Text('¿Desea activar el desbloqueo por huella/FaceID para mayor comodidad?'),
            actions: [
              CupertinoDialogAction(
                child: const Text('No'),
                onPressed: () => Navigator.pop(context, false),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Activar'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
        
        if (useBio == true) {
          final authenticated = await SecurityService.authenticateWithBiometrics(
            reason: 'Confirma tu identidad para activar biometría',
          );
          if (authenticated) {
            await SecurityService.setBiometricsEnabled(true);
          }
        }
      }
      
      if (!mounted) return;
      Navigator.pop(context, true); // Retorna true indicando que se configuró
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _confirmPin = '';
        _errorMessage = 'Los PIN no coinciden. Intente de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text(_isConfirming ? 'Confirmar PIN' : 'Crear PIN'),
        backgroundColor: Colors.transparent,
        border: null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            FadeSlideIn(
              child: Column(
                children: [
                  Icon(
                    _isConfirming ? CupertinoIcons.checkmark_shield : CupertinoIcons.lock_shield,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isConfirming ? 'Confirma tu nuevo PIN' : 'Crea tu PIN de acceso',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa 4 dígitos para proteger tu app',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            _buildPinIndicators(),
            
            const SizedBox(height: 16),
            
            SizedBox(
              height: 24,
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            
            const Spacer(),
            
            _buildKeypad(isDark),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPinIndicators() {
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isActive = index < currentLength;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
                ? AppColors.primary 
                : (Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white12 
                    : Colors.grey.shade200),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey(1), _buildKey(2), _buildKey(3),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey(4), _buildKey(5), _buildKey(6),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey(7), _buildKey(8), _buildKey(9),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 72),
              _buildKey(0),
              _buildDeleteKey(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(int number) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OptimizedPressButton(
      onTap: () => _onNumberPressed(number),
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
