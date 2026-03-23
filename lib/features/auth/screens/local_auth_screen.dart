import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/services/security_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/animations/optimized_animations.dart';

class LocalAuthScreen extends StatefulWidget {
  const LocalAuthScreen({super.key});

  @override
  State<LocalAuthScreen> createState() => _LocalAuthScreenState();
}

class _LocalAuthScreenState extends State<LocalAuthScreen> {
  String _currentPinInput = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final useBiometrics = await SecurityService.isBiometricsEnabled();
    if (useBiometrics) {
      _authenticateBiometrics();
    }
  }

  Future<void> _authenticateBiometrics() async {
    final authenticated = await SecurityService.authenticateWithBiometrics();

    if (authenticated) {
      _onSuccess();
    }
  }

  void _onNumberPressed(int number) {
    if (_currentPinInput.length < 4) {
      setState(() {
        _currentPinInput += number.toString();
        _errorMessage = null;
      });

      if (_currentPinInput.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_currentPinInput.isNotEmpty) {
      setState(() {
        _currentPinInput = _currentPinInput.substring(0, _currentPinInput.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await SecurityService.verifyPin(_currentPinInput);
    if (isValid) {
      _onSuccess();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _currentPinInput = '';
        _errorMessage = 'PIN Incorrecto';
      });
    }
  }

  void _onSuccess() {
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _onLogoutPressed() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro que desea cerrar sesión? Se borrará su configuración de PIN y huella.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cerrar Sesión'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TokenStorage.deleteToken();
      await SecurityService.clearSecurityData();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Logo & Header
            FadeSlideIn(
              child: Column(
                children: [
                  _buildLogo(isDark),
                  const SizedBox(height: 24),
                  Text(
                    'Desbloquea tu App',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa tu PIN de seguridad',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            // PIN Indicators
            _buildPinIndicators(),
            
            const SizedBox(height: 16),
            
            // Error Message
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
            
            // Numeric Keypad
            _buildKeypad(isDark),
            
            const SizedBox(height: 24),
            
            // Logout Option
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
    );
  }

  Widget _buildLogo(bool isDark) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF2C2C2E) : AppColors.white,
        boxShadow: isDark ? [] : AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Image.asset(
          'assets/images/cossmil_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPinIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool isActive = index < _currentPinInput.length;
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
            border: Border.all(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
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
              _buildBiometricKey(), _buildKey(0), _buildDeleteKey(),
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

  Widget _buildBiometricKey() {
    return FutureBuilder<bool>(
      future: SecurityService.isBiometricsEnabled(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return OptimizedPressButton(
            onTap: _authenticateBiometrics,
            child: const SizedBox(
              width: 72,
              height: 72,
              child: Icon(
                CupertinoIcons.device_phone_portrait, // Simula FaceID/Huella
                size: 32,
                color: AppColors.primary,
              ),
            ),
          );
        }
        return const SizedBox(width: 72, height: 72);
      },
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
