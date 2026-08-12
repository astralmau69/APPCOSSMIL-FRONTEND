import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/password_feedback.dart';

/// Pantalla obligatoria de actualización de datos para primer ingreso.
/// Se muestra cuando `req_reset == false` en el token de login.
class PasswordChangeScreen extends StatefulWidget {
  const PasswordChangeScreen({super.key});

  @override
  State<PasswordChangeScreen> createState() => _PasswordChangeScreenState();
}

class _PasswordChangeScreenState extends State<PasswordChangeScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _bloodTypeCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final email = UserSession.currentUser.email;
    if (email.isNotEmpty) _emailCtrl.text = email;
    final phone = UserSession.currentUser.phone;
    if (phone.isNotEmpty) _phoneCtrl.text = phone;
    final allergies = UserSession.currentUser.allergies;
    if (allergies.isNotEmpty) _allergiesCtrl.text = allergies;
    final bloodType = UserSession.currentUser.bloodType;
    if (bloodType.isNotEmpty) _bloodTypeCtrl.text = bloodType;

    // Redibuja la lista de requisitos y la barra en cada pulsación.
    _passwordCtrl.addListener(_onPasswordChanged);
    _confirmCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _allergiesCtrl.dispose();
    _bloodTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    // Sin .trim(): recortar altera en silencio la contraseña que se guarda
    // respecto de la que el usuario tecleó.
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final allergies = _allergiesCtrl.text.trim();
    final bloodType = _bloodTypeCtrl.text.trim();

    if (password.isEmpty || confirm.isEmpty || email.isEmpty || phone.isEmpty) {
      setState(
        () => _errorMessage =
            'Los campos de contraseña, correo y teléfono son obligatorios.',
      );
      return;
    }

    // Misma política que el sheet de Perfil: antes aquí solo se exigían 6
    // caracteres, así que se podía fijar en el primer ingreso una contraseña
    // que Perfil habría rechazado después.
    final unmet = PasswordPolicy.unmet(password);
    if (unmet.isNotEmpty) {
      setState(
        () => _errorMessage =
            'La contraseña aún no cumple: '
            '${unmet.map(PasswordPolicy.labelFor).join(', ')}.',
      );
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Ingrese un correo electrónico válido.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      await _authService.updateUsuarioWeb(
        idper: idper,
        password: password,
        email: email,
        phone: phone,
        bloodType: bloodType,
        allergies: allergies,
      );

      if (!mounted) return;

      UserSession.currentUser = UserSession.currentUser.copyWith(
        email: email,
        phone: phone,
        bloodType: bloodType.isNotEmpty
            ? bloodType
            : UserSession.currentUser.bloodType,
        allergies: allergies.isNotEmpty
            ? allergies
            : UserSession.currentUser.allergies,
      );

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorMapper.message(
          e,
          context: ErrorContext.cambiarPassword,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return AppBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg(isDark),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: r.screenPadding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.vertical,
                  maxWidth: r.isTablet ? 500 : double.infinity,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: context.r.spaceXl),

                    // ── Logo COSSMIL ─────────────────────────────────
                    FadeSlideIn(
                      child: Image.asset(
                        'assets/images/cossmil_logo.png',
                        width: (context.r.screenHeight * 0.10).clamp(
                          64.0,
                          100.0,
                        ),
                        height: (context.r.screenHeight * 0.10).clamp(
                          64.0,
                          100.0,
                        ),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: (context.r.screenHeight * 0.10).clamp(
                            64.0,
                            100.0,
                          ),
                          height: (context.r.screenHeight * 0.10).clamp(
                            64.0,
                            100.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.shield_lefthalf_fill,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.r.spaceLg),

                    // ── Título principal ───────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        'Actualización de Datos',
                        style: context.texts.headlineLarge.copyWith(
                          color: AppColors.textPrimaryC(isDark),
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: context.r.spaceXl),

                    // ═══ SECCIÓN: Contraseña ══════════════════════════
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: _sectionHeader(
                        icon: CupertinoIcons.lock_shield_fill,
                        title: 'Actualización de Contraseña',
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 200),
                      child: _buildField(
                        label: 'Nueva Contraseña',
                        controller: _passwordCtrl,
                        placeholder: 'Ingrese su nueva contraseña',
                        icon: CupertinoIcons.lock_fill,
                        isDark: isDark,
                        obscureText: _obscurePassword,
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          child: Icon(
                            _obscurePassword
                                ? CupertinoIcons.eye_slash_fill
                                : CupertinoIcons.eye_fill,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: _buildField(
                        label: 'Confirmar Contraseña',
                        controller: _confirmCtrl,
                        placeholder: 'Repita su nueva contraseña',
                        icon: CupertinoIcons.lock_shield_fill,
                        isDark: isDark,
                        obscureText: _obscureConfirm,
                        trailing: CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          child: Icon(
                            _obscureConfirm
                                ? CupertinoIcons.eye_slash_fill
                                : CupertinoIcons.eye_fill,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: context.r.spaceMd),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 275),
                      child: PasswordFeedback(
                        password: _passwordCtrl.text,
                        confirm: _confirmCtrl.text,
                      ),
                    ),

                    SizedBox(height: context.r.spaceLg),

                    // ═══ SECCIÓN: Correo electrónico ══════════════════
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 300),
                      child: _sectionHeader(
                        icon: CupertinoIcons.mail_solid,
                        title: 'Actualización de Correo Electrónico',
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 350),
                      child: _buildField(
                        label: 'Correo Electrónico',
                        controller: _emailCtrl,
                        placeholder: 'ejemplo@correo.com',
                        icon: CupertinoIcons.mail_solid,
                        isDark: isDark,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),

                    SizedBox(height: context.r.spaceLg),

                    // ═══ SECCIÓN: Número de celular ═══════════════════
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 400),
                      child: _sectionHeader(
                        icon: CupertinoIcons.phone_fill,
                        title: 'Actualización de Número de Celular',
                        isDark: isDark,
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: _buildField(
                        label: 'Número de Celular',
                        controller: _phoneCtrl,
                        placeholder: 'Ej. 70012345',
                        icon: CupertinoIcons.phone_fill,
                        isDark: isDark,
                        keyboardType: TextInputType.phone,
                      ),
                    ),

                    SizedBox(height: context.r.spaceLg),

                    // ═══ SECCIÓN: Datos Médicos ═══════════════════════

                    // ── Error ───────────────────────────────────────
                    if (_errorMessage != null) ...[
                      FadeSlideIn(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(
                              context.r.radiusMd,
                            ),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: AppColors.error,
                                size: 20,
                              ),
                              SizedBox(width: context.r.spaceMd),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: context.texts.bodyMedium.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: context.r.spaceMd),
                    ],

                    // ── Botón guardar ──────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 500),
                      child: SizedBox(
                        width: double.infinity,
                        height: r.buttonHeight,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(
                            context.r.buttonRadius,
                          ),
                          onPressed: _isLoading ? null : _onSubmit,
                          child: _isLoading
                              ? const CupertinoActivityIndicator(
                                  color: AppColors.white,
                                )
                              : Text(
                                  'Guardar y Continuar',
                                  style: context.texts.titleMedium.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.r.spaceXxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Header de sección con ícono y título
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accentForTheme(isDark)),
        SizedBox(width: context.r.spaceSm),
        Expanded(
          child: Text(
            title,
            style: context.texts.titleMedium.copyWith(
              color: AppColors.accentForTheme(isDark),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(context.r.cardRadius),
        border: Border.all(color: AppColors.cardBorder(isDark)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.accentForTheme(isDark)),
          SizedBox(width: context.r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.texts.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: context.r.spaceXs),
                CupertinoTextField(
                  controller: controller,
                  obscureText: obscureText,
                  enabled: !_isLoading,
                  keyboardType: keyboardType,
                  padding: EdgeInsets.zero,
                  decoration: null,
                  placeholder: placeholder,
                  placeholderStyle: TextStyle(
                    color: AppColors.textTertiaryC(
                      isDark,
                    ).withValues(alpha: 0.6),
                  ),
                  style: context.texts.bodyLarge.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.r.spaceSm),
            trailing,
          ],
        ],
      ),
    );
  }
}
