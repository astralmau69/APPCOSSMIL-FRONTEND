import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/animations/fade_slide_in.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS System Grey 6
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableHeight = constraints.maxHeight;
            final double logoSize = availableHeight < 600 ? 90 : 120;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      // SECCIÓN DE MARCA
                      FadeSlideIn(
                        offsetY: 30,
                        child: Column(
                          children: [
                            _buildLogo(logoSize),
                            const SizedBox(height: 24),
                            _buildHeader(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // SECCIÓN DE FORMULARIO (iOS Inset Grouped style)
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 200),
                        offsetY: 30,
                        child: Column(
                          children: [
                            _buildForm(),
                            const SizedBox(height: 32),
                            if (_errorMessage != null) ...[
                              _buildErrorBanner(),
                              const SizedBox(height: 20),
                            ],
                            _buildLoginButton(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // ACCIONES ADICIONALES
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 400),
                        child: _buildForgotPassword(),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/cossmil_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              CupertinoIcons.shield_fill,
              size: size * 0.4,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Iniciar Sesión',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'INGRESA TUS CREDENCIALES',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
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
            height: 0.5,
            thickness: 0.5,
            indent: 54,
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
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: -0.1,
                  ),
                ),
                TextField(
                  controller: controller,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  textCapitalization: textCapitalization,
                  onChanged: onChanged,
                  textAlign: TextAlign.left,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 4, bottom: 8),
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                      fontSize: 17,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
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
            const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5E5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle_fill,
                color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _isLoading ? null : _onLoginPressed,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: _isLoading
              ? const CupertinoActivityIndicator(color: AppColors.white)
              : const Text(
                  'Ingresar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        // TODO: navegar a recuperar contraseña
      },
      child: const Text(
        '¿Olvidaste tu contraseña?',
        style: TextStyle(
          fontSize: 15,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
