import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/storage/token_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Colores centralizados
  static const Color _olive = AppColors.olive;
  static const Color _bgGrey = AppColors.bgGrey;
  static const Color _errorRed = AppColors.errorRed;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Lógica ──────────────────────────────────────────────────────────────

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

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _bgGrey,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              _buildLogo(),
              const SizedBox(height: 28),
              _buildTitle(),
              const SizedBox(height: 32),
              _buildFormCard(),
              const SizedBox(height: 12),
              _buildForgotPassword(),
              const SizedBox(height: 28),
              if (_errorMessage != null) ...[
                _buildErrorBanner(),
                const SizedBox(height: 16),
              ],
              _buildLoginButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 110,
      height: 110,
      child: Image.asset(
        'assets/images/cossmil_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _olive, width: 2.5),
          ),
          child: const Icon(
            CupertinoIcons.shield_fill,
            size: 54,
            color: _olive,
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      children: [
        Text(
          'Iniciar Sesión',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.black,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Ingresa tu matrícula para reservar\ntu ficha médica.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: CupertinoColors.secondaryLabel,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFormRow(
            label: 'Matrícula',
            controller: _usernameController,
            placeholder: 'Ej. 2051986',
            obscureText: false,
            isLast: false,
          ),
          Container(height: 0.5, color: const Color(0xFFE0E0E0)),
          _buildFormRow(
            label: 'Clave',
            controller: _passwordController,
            placeholder: '••••••••',
            obscureText: _obscurePassword,
            isLast: true,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 30,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? CupertinoIcons.eye_slash
                    : CupertinoIcons.eye,
                size: 18,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required bool obscureText,
    required bool isLast,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.label,
              ),
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              obscureText: obscureText,
              enabled: !_isLoading,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(),
              style: const TextStyle(fontSize: 15),
              placeholderStyle: const TextStyle(
                color: CupertinoColors.placeholderText,
                fontSize: 15,
              ),
              textInputAction:
                  isLast ? TextInputAction.done : TextInputAction.next,
              onSubmitted: isLast ? (_) => _onLoginPressed() : null,
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          // TODO: navegar a recuperar contraseña
        },
        child: const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            fontSize: 14,
            color: _olive,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _errorRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle,
              color: _errorRed, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style:
                  const TextStyle(color: _errorRed, fontSize: 13.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        onPressed: _isLoading ? null : _onLoginPressed,
        color: _olive,
        disabledColor: _olive.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: _isLoading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : const Text(
                'Ingresar',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
