import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../animations/app_dialog.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';
import 'liquid_glass.dart';

/// Diálogo de ayuda del Grupo Familiar: explica el conducto correcto cuando
/// el titular detecta un error o inconsistencia con algún miembro (p. ej. un
/// familiar que aparece "Sin atención" cuando debería estar habilitado).
///
/// Orden del procedimiento (los pasos se muestran numerados):
///   1. Verificar el estado en el área de **Afiliaciones**.
///   2. Recién entonces, acudir al área de **DNTIC**.
///
/// Vive en `core/widgets/` porque lo usan tanto `FamiliaScreen` como el
/// `BeneficiarySelectorModal` (core), y core no debe importar de `features/`.
///
/// Entrada/salida animadas por [showAppDialog] (fade + micro-escala,
/// respetando reduce-motion).
Future<void> showFamiliaHelpDialog(BuildContext context) {
  return showAppDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Información del grupo familiar',
    builder: (_) => const _FamiliaHelpDialog(),
  );
}

class _FamiliaHelpDialog extends StatelessWidget {
  const _FamiliaHelpDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentForTheme(isDark);

    // SafeArea + scroll: en viewports bajos (ventana web chica, split-screen,
    // escala de texto grande) el contenido se desplaza en vez de cortarse;
    // si cabe completo, queda centrado como siempre.
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            // El diálogo vive fuera del árbol Material de la pantalla: sin esto
            // los Text heredarían el estilo de emergencia (subrayado amarillo).
            child: DefaultTextStyle(
              style: TextStyle(
                decoration: TextDecoration.none,
                fontSize: 14,
                color: AppColors.textPrimaryC(isDark),
              ),
              // Vidrio real (blur): superficie arquitectónica única en
              // pantalla, permitido por la regla de rendimiento.
              child: LiquidGlass(
                isDark: isDark,
                blur: true,
                borderRadius: BorderRadius.circular(22),
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                shadow: AppColors.cardShadowFor(isDark),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Ícono ──
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.20 : 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.question_circle_fill,
                          size: 30,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '¿Un dato incorrecto?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Si detecta un error o inconsistencia con algún miembro de '
                      'su grupo familiar, siga estos pasos en orden:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // ── Pasos ──
                    _HelpStep(
                      number: '1',
                      accent: accent,
                      isDark: isDark,
                      title: 'Verifique en Afiliaciones',
                      detail:
                          'Confirme primero el estado del afiliado en el área '
                          'de Afiliaciones.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _HelpStep(
                      number: '2',
                      accent: accent,
                      isDark: isDark,
                      title: 'Luego acuda a DNTIC',
                      detail:
                          'Si el dato sigue incorrecto, comuníquese con el área '
                          'de DNTIC para su corrección.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LiquidGlassButton(
                      label: 'Entendido',
                      color: accent,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de un paso numerado: círculo con el número + título y detalle.
class _HelpStep extends StatelessWidget {
  final String number;
  final String title;
  final String detail;
  final Color accent;
  final bool isDark;

  const _HelpStep({
    required this.number,
    required this.title,
    required this.detail,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.textPrimaryC(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: AppColors.textSecondaryC(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
