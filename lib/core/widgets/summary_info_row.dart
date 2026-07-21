import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Fila de información (ícono + etiqueta + valor) del resumen de reserva.
/// Extraída de `SummaryScreen._infoRow` para reutilizarla también en el
/// tutorial guiado — mismo componente en ambos lugares.
class SummaryInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const SummaryInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.chipPaddingV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(r.spaceSm),
            decoration: BoxDecoration(
              color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.textTertiaryC(isDark)),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryC(isDark),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Separador delgado entre filas de resumen. Extraído de
/// `SummaryScreen._divider`.
class SummaryDivider extends StatelessWidget {
  final bool isDark;

  const SummaryDivider({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: isDark ? AppColors.darkDivider : const Color(0xFF191C1E).withValues(alpha: 0.05),
      ),
    );
  }
}
