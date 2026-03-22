import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/storage/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Ingrese su matrícula y clave.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.login(
      username: username,
      password: password,
    );

    if (!mounted) return;

    switch (result) {
      case AuthSuccess(:final token):
        await TokenStorage.saveToken(token.accessToken);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');

      case AuthError(:final message):
        setState(() {
          _isLoading = false;
          _errorMessage = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveData.of(context);
    final padding = responsive.isSmallPhone ? 16.0 : (responsive.isPhone ? 20.0 : 32.0);
    final logoSize = responsive.isSmallPhone ? 80.0
        : responsive.isMediumPhone ? 100.0
        : responsive.isLargePhone ? 110.0
        : 120.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: responsive.screenHeight - MediaQuery.of(context).padding.vertical,
            ),
            child: Center(
              child: ResponsiveContainer(
                maxWidth: responsive.isTablet ? 500 : double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Logo
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      child: _buildLogo(logoSize),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Header
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      delay: const Duration(milliseconds: 100),
                      child: _buildHeader(responsive),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Form
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 200),
                      child: _buildForm(responsive),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Error message
                    if (_errorMessage != null) ...[
                      FadeSlideIn(
                        duration: AppDurations.fast,
                        child: _buildErrorBanner(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Login button
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 250),
                      child: _buildLoginButton(),
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Forgot password
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 300),
                      child: _buildForgotPassword(),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        boxShadow: AppShadows.soft,
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/cossmil_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              CupertinoIcons.shield_fill,
              size: size * 0.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ResponsiveData responsive) {
    final isSmall = responsive.isSmallPhone;
    
    return Column(
      children: [
        Text(
          'Iniciar Sesión',
          style: isSmall ? AppTypography.displayMedium : AppTypography.displayLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'INGRESA TUS CREDENCIALES',
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(ResponsiveData responsive) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          _buildInputField(
            label: 'Matrícula',
            controller: _usernameController,
            placeholder: 'Ej. 010325AQJ',
            icon: CupertinoIcons.person_crop_circle,
            isLast: false,
            textCapitalization: TextCapitalization.characters,
            onChanged: (val) {
              if (val != val.toUpperCase()) {
                _usernameController.value = _usernameController.value.copyWith(
                  text: val.toUpperCase(),
                  selection: _usernameController.selection,
                );
              }
            },
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: responsive.isPhone ? 54 : 60,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
          _buildInputField(
            label: 'Contraseña',
            controller: _passwordController,
            placeholder: 'Requerido',
            icon: CupertinoIcons.lock_fill,
            obscureText: _obscurePassword,
            isLast: true,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    required bool isLast,
    Widget? trailing,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                Text(
                  label,
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: controller,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  textAlign: TextAlign.left,
                  placeholder: placeholder,
                  placeholderStyle: TextStyle(
                    color: AppColors.textTertiary.withValues(alpha: 0.4),
                    fontSize: 16,
                  ),
                  decoration: null,
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  style: AppTypography.bodyLarge,
                  textInputAction:
                      isLast ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: isLast ? (_) => _onLoginPressed() : null,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OptimizedPressButton(
        onTap: _isLoading ? null : _onLoginPressed,
        scaleDown: 0.95,
        child: Container(
          decoration: BoxDecoration(
            color: _isLoading ? AppColors.textSecondary : AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: AppShadows.medium,
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(
                    'INICIAR SESIÓN',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Center(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {},
        child: Text(
          '¿Olvidó su contraseña?',
          style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}
