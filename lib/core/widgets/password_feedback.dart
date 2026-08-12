import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/app_constants.dart';
import '../utils/password_policy.dart';

/// Barra de seguridad de 4 niveles. Informativa: no bloquea el envío.
class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  static Color colorFor(PasswordStrength s) => switch (s) {
    PasswordStrength.muyDebil => AppColors.error,
    PasswordStrength.debil => const Color(0xFFEA580C),
    PasswordStrength.buena => AppColors.warning,
    PasswordStrength.fuerte => AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final strength = PasswordPolicy.strengthOf(password);
    final color = colorFor(strength);
    // Vacío = 0; si no, una cuarta parte por nivel.
    final fraction = password.isEmpty ? 0.0 : (strength.index + 1) / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Seguridad',
              style: context.texts.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            // AnimatedSwitcher para que la etiqueta no "salte" al cambiar.
            AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              child: Text(
                password.isEmpty
                    ? ''
                    : PasswordPolicy.labelForStrength(strength),
                key: ValueKey(password.isEmpty ? '' : strength),
                style: context.texts.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(r.radiusSm),
          child: Stack(
            children: [
              Container(height: 6, color: AppColors.cardBorder(isDark)),
              // FractionallySizedBox se adapta al ancho disponible: la barra
              // nunca fuerza un ancho propio, así funciona igual en 320 px que
              // en un sheet de tablet.
              AnimatedFractionallySizedBox(
                duration: reduceMotion ? Duration.zero : AppDurations.quick,
                curve: AppCurves.snappy,
                widthFactor: fraction,
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lista de requisitos que se van tildando en vivo mientras el usuario escribe.
class PasswordChecklist extends StatelessWidget {
  final String password;

  /// Si no es null, se añade la fila "Las contraseñas coinciden".
  final String? confirm;

  const PasswordChecklist({super.key, required this.password, this.confirm});

  @override
  Widget build(BuildContext context) {
    final unmet = PasswordPolicy.unmet(password);

    final rows = <Widget>[
      for (final rule in PasswordRule.values)
        _RequirementRow(
          label: PasswordPolicy.labelFor(rule),
          met: !unmet.contains(rule),
        ),
      if (confirm != null)
        _RequirementRow(
          label: 'Las contraseñas coinciden',
          met: password.isNotEmpty && password == confirm,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool met;

  const _RequirementRow({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final color = met ? AppColors.success : AppColors.textTertiaryC(isDark);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spaceXs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.iconSm,
            height: r.iconSm,
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              switchInCurve: AppCurves.snappy,
              child: met
                  ? Icon(
                      CupertinoIcons.checkmark_alt,
                      key: const ValueKey('met'),
                      size: r.iconSm,
                      color: AppColors.success,
                    )
                  : Icon(
                      CupertinoIcons.circle,
                      key: const ValueKey('unmet'),
                      size: r.iconSm * 0.7,
                      color: AppColors.textTertiaryC(isDark),
                    ),
            ),
          ),
          SizedBox(width: r.spaceSm),
          // Expanded: las etiquetas largas envuelven en vez de desbordar en
          // pantallas de 320 px.
          Expanded(
            child: Text(
              label,
              style: context.texts.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de seguridad + lista de requisitos, con el espaciado del sistema.
class PasswordFeedback extends StatelessWidget {
  final String password;
  final String? confirm;

  const PasswordFeedback({super.key, required this.password, this.confirm});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PasswordStrengthBar(password: password),
        SizedBox(height: r.spaceMd),
        PasswordChecklist(password: password, confirm: confirm),
      ],
    );
  }
}
