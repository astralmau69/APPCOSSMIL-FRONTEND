import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/session_restore_service.dart';
import '../../../core/session/user_session.dart';

class EmergencyDataScreen extends StatefulWidget {
  const EmergencyDataScreen({super.key});

  @override
  State<EmergencyDataScreen> createState() => _EmergencyDataScreenState();
}

class _EmergencyDataScreenState extends State<EmergencyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _refCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = UserSession.currentUser;
    _phoneCtrl = TextEditingController(text: user.emergencyPhone);
    _refCtrl = TextEditingController(text: user.referencia);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      final user = UserSession.currentUser;
      final idper = int.tryParse(user.id) ?? 0;
      final phone = _phoneCtrl.text.trim();
      final ref = _refCtrl.text.trim();

      final message = await AuthService().actualizarDatosPer(
        idper: idper,
        telfemerg: phone,
        referencia: ref,
        matricula: user.matricula,
      );

      if (!mounted) return;

      UserSession.currentUser = user.copyWith(
        emergencyPhone: phone,
        referencia: ref,
      );
      await SessionRestoreService.saveUserSession(UserSession.currentUser);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Regresar al perfil y pasar el mensaje para mostrarlo allá
      Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('$e'.replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showSnackBar(String text, {required bool isError}) {
    final r = context.r;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? CupertinoIcons.xmark_circle_fill
                  : CupertinoIcons.checkmark_circle_fill,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: r.spaceSm),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.radiusMd),
        ),
        margin: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool isDark,
    required Color accentColor,
  }) {
    final r = context.r;
    final borderColor = AppColors.cardBorder(isDark);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: context.texts.bodyMedium.copyWith(
        color: AppColors.textSecondaryC(isDark),
      ),
      hintStyle: context.texts.bodyMedium.copyWith(
        color: AppColors.textTertiaryC(isDark),
      ),
      prefixIcon: Padding(
        padding: EdgeInsets.only(left: r.spaceMd, right: r.spaceSm),
        child: Icon(prefixIcon, color: accentColor, size: r.iconSm),
      ),
      prefixIconConstraints: const BoxConstraints(),
      filled: true,
      fillColor: isDark
          ? AppColors.darkElevated
          : AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.inputRadius),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.inputRadius),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.inputRadius),
        borderSide: BorderSide(color: accentColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.inputRadius),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.inputRadius),
        borderSide: const BorderSide(color: AppColors.error, width: 1.8),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: r.cardPadding,
        vertical: r.spaceMd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final accentColor = AppColors.accentForTheme(isDark);
    final borderColor = AppColors.cardBorder(isDark);

    return AppBackground(
      isDark: isDark,
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(
            'Datos de Emergencia',
            style: TextStyle(
              color: AppColors.textPrimaryC(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: isDark
              ? AppColors.darkSurface.withValues(alpha: 0.92)
              : AppColors.white.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: borderColor.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        backgroundColor: isDark ? Colors.transparent : AppColors.background,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  r.paddingH,
                  r.spaceLg,
                  r.paddingH,
                  r.navBarBottomSpace,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: r.maxContentWidth),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Banner informativo ────────────────────────────
                          Container(
                            padding: EdgeInsets.all(r.cardPadding),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard.withValues(alpha: 0.7)
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(r.radiusMd),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.exclamationmark_shield_fill,
                                  color: accentColor,
                                  size: r.iconMd,
                                ),
                                SizedBox(width: r.spaceMd),
                                Expanded(
                                  child: Text(
                                    'Esta información se utiliza para contactar a su familia en casos de emergencia médica.',
                                    style: context.texts.bodySmall.copyWith(
                                      color: AppColors.textSecondaryC(isDark),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: r.spaceLg),

                          // ── Card principal ────────────────────────────────
                          LiquidGlass(
                            isDark: isDark,
                            borderRadius: BorderRadius.circular(r.cardRadius),
                            padding: EdgeInsets.all(r.cardPadding),
                            shadow: AppColors.cardShadowFor(isDark),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Etiqueta de sección
                                Text(
                                  'CONTACTO DE EMERGENCIA',
                                  style: context.texts.labelSmall.copyWith(
                                    color: AppColors.textTertiaryC(isDark),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                SizedBox(height: r.spaceLg),

                                // Campo: Teléfono de Emergencia
                                TextFormField(
                                  controller: _phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  style: context.texts.bodyLarge.copyWith(
                                    color: AppColors.textPrimaryC(isDark),
                                  ),
                                  decoration: _inputDeco(
                                    label: 'Teléfono de Emergencia',
                                    hint: '7XXXXXXX',
                                    prefixIcon: CupertinoIcons.phone_fill,
                                    isDark: isDark,
                                    accentColor: accentColor,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Ingresa un número de teléfono de emergencia';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: r.spaceMd),

                                // Campo: Referencia
                                TextFormField(
                                  controller: _refCtrl,
                                  keyboardType: TextInputType.name,
                                  textInputAction: TextInputAction.done,
                                  textCapitalization: TextCapitalization.words,
                                  onFieldSubmitted: (_) {
                                    if (!_isLoading) _submit();
                                  },
                                  style: context.texts.bodyLarge.copyWith(
                                    color: AppColors.textPrimaryC(isDark),
                                  ),
                                  decoration: _inputDeco(
                                    label: 'Referencia',
                                    hint: 'Ej: Mamá, Esposo, Hermana...',
                                    prefixIcon: CupertinoIcons.person_2_fill,
                                    isDark: isDark,
                                    accentColor: accentColor,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Ingresa una referencia del contacto';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: r.spaceXl),

                          // ── Botón principal ───────────────────────────────
                          SizedBox(
                            height: r.buttonHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                disabledBackgroundColor: accentColor.withValues(
                                  alpha: 0.45,
                                ),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    r.buttonRadius,
                                  ),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isLoading
                                    ? const SizedBox(
                                        key: ValueKey('loading'),
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Row(
                                        key: const ValueKey('label'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            CupertinoIcons
                                                .checkmark_shield_fill,
                                            size: r.iconSm,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: r.spaceSm),
                                          Text(
                                            'Actualizar Datos',
                                            style: context.texts.labelLarge
                                                .copyWith(color: Colors.white),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
