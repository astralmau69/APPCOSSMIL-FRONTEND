import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/services/location_service.dart';

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
  final _locationService = LocationService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

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

        // Mostrar un pequeño indicador en UI mientras pide la ubicación si lo deseamos, 
        // pero requestPermission abrirá un popup del OS.
        await _locationService.requestPermission();

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
    final padding = responsive.isSmallPhone ? 16.0 : (responsive.isPhone ? 24.0 : 32.0);
    final logoSize = responsive.isSmallPhone ? 90.0
        : responsive.isMediumPhone ? 110.0
        : 130.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                maxWidth: responsive.isTablet ? 450 : double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Logo
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      child: _buildLogo(logoSize, isDark),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Header
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      delay: const Duration(milliseconds: 100),
                      child: _buildHeader(),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Form
                    FadeSlideIn(
                      duration: AppDurations.normal,
                      delay: const Duration(milliseconds: 200),
                      child: _buildForm(isDark),
                    ),
                    
                    const SizedBox(height: 24),
                    
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
                    
                    const SizedBox(height: 32),
                    
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

  Widget _buildLogo(double size, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF2C2C2E) : AppColors.white,
        boxShadow: isDark ? [] : AppShadows.soft,
        border: isDark ? Border.all(color: Colors.white10) : null,
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: Image.asset(
            'assets/images/cossmil_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              CupertinoIcons.shield_fill,
              size: size * 0.5,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Bienvenido',
          style: AppTypography.displayMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingrese sus credenciales de COSSMIL',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm(bool isDark) {
    return Column(
      children: [
        _buildModernInputField(
          label: 'Matrícula',
          controller: _usernameController,
          placeholder: 'Ej. 010325AQJ',
          icon: CupertinoIcons.person_crop_circle,
          isDark: isDark,
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
        const SizedBox(height: 16),
        _buildModernInputField(
          label: 'Contraseña',
          controller: _passwordController,
          placeholder: 'Su contraseña',
          icon: CupertinoIcons.lock_fill,
          obscureText: _obscurePassword,
          isDark: isDark,
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
    );
  }

  Widget _buildModernInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    bool obscureText = false,
    bool isLast = false,
    bool isDark = false,
    Widget? trailing,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: isDark ? AppColors.white : AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                CupertinoTextField(
                  controller: controller,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  padding: EdgeInsets.zero,
                  decoration: null,
                  placeholder: placeholder,
                  placeholderStyle: TextStyle(
                    color: isDark ? Colors.white30 : AppColors.textTertiary.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  style: AppTypography.bodyLarge.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                  onSubmitted: isLast ? (_) => _onLoginPressed() : null,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OptimizedPressButton(
        onTap: _isLoading ? null : _onLoginPressed,
        scaleDown: 0.95,
        child: Container(
          decoration: BoxDecoration(
            color: _isLoading ? AppColors.textSecondary : AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isLoading ? [] : [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(
                    'Iniciar Sesión',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {},
        child: Text(
          '¿Olvidó su contraseña?',
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
