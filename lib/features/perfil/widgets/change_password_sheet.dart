import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/animations/app_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/password_feedback.dart';

/// Abre el sheet de cambio de contraseña. Devuelve `true` si se cambió.
Future<bool?> showChangePasswordSheet(BuildContext context) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const ChangePasswordSheet(),
  );
}

/// Formulario de cambio de contraseña con retroalimentación en vivo.
///
/// Sustituye al CupertinoAlertDialog anterior, cuyo ancho fijo no admitía la
/// lista de requisitos ni la barra de seguridad, y que solo informaba del
/// rechazo DESPUÉS de pulsar Guardar.
class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Redibuja la lista y la barra en cada pulsación.
    _pwdCtrl.addListener(_onChanged);
    _confirmCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() => _errorMessage = null);
  }

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // NO se usa .trim(): recortar altera en silencio la contraseña que se guarda
  // respecto de la que el usuario tecleó.
  bool get _canSubmit =>
      !_isSaving &&
      PasswordPolicy.isValid(_pwdCtrl.text) &&
      _pwdCtrl.text == _confirmCtrl.text;

  Future<void> _onSubmit() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      await AuthService().changePassword(
        idper: idper,
        newPassword: _pwdCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        // El backend puede rechazar ciertos caracteres especiales: su mensaje
        // real importa más que un genérico.
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

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.modalMaxWidth),
        child: Material(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(r.modalRadius),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            // El teclado no debe tapar el botón ni la lista.
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.all(r.modalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cambiar contraseña',
                    style: context.texts.titleLarge.copyWith(
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  SizedBox(height: r.spaceLg),
                  _field(
                    controller: _pwdCtrl,
                    placeholder: 'Nueva contraseña',
                    obscure: _obscurePwd,
                    onToggle: () => setState(() => _obscurePwd = !_obscurePwd),
                    isDark: isDark,
                    autofocus: true,
                  ),
                  SizedBox(height: r.spaceSm),
                  _field(
                    controller: _confirmCtrl,
                    placeholder: 'Confirmar contraseña',
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    isDark: isDark,
                  ),
                  SizedBox(height: r.spaceLg),
                  PasswordFeedback(
                    password: _pwdCtrl.text,
                    confirm: _confirmCtrl.text,
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: r.spaceMd),
                    Text(
                      _errorMessage!,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  SizedBox(height: r.spaceLg),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isSaving
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancelar',
                            style: context.texts.titleMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: r.spaceSm),
                      Expanded(
                        child: SizedBox(
                          height: r.buttonHeight,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(r.buttonRadius),
                            // Deshabilitado hasta cumplir todo: el rechazo deja
                            // de ser una sorpresa post-envío.
                            onPressed: _canSubmit ? _onSubmit : null,
                            child: _isSaving
                                ? const CupertinoActivityIndicator(
                                    color: AppColors.white,
                                  )
                                : Text(
                                    'Cambiar contraseña',
                                    textAlign: TextAlign.center,
                                    style: context.texts.titleMedium.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String placeholder,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
    bool autofocus = false,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscure,
      autofocus: autofocus,
      enabled: !_isSaving,
      padding: EdgeInsets.symmetric(
        horizontal: context.r.tileHorizontalPad,
        vertical: context.r.spaceMd,
      ),
      decoration: BoxDecoration(
        // darkBackground (no darkBg, que no existe): más oscuro que el
        // darkCard del sheet, igual que el gris claro sobre blanco en claro.
        color: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(context.r.inputRadius),
        border: Border.all(color: AppColors.cardBorder(isDark)),
      ),
      style: context.texts.bodyLarge.copyWith(
        color: AppColors.textPrimaryC(isDark),
      ),
      suffix: CupertinoButton(
        padding: EdgeInsets.only(right: context.r.spaceSm),
        minimumSize: Size.zero,
        onPressed: onToggle,
        child: Icon(
          obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
          size: context.r.iconSm,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
