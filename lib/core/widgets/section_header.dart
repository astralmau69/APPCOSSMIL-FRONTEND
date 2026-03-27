import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';

/// Widget reutilizable para cabeceras de sección con estilo consistente.
///
/// Muestra una barra de acento vertical + texto uppercase con tracking.
class SectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;
  final bool showAccentBar;

  const SectionHeader({
    super.key,
    required this.text,
    this.padding = const EdgeInsets.only(left: 24),
    this.showAccentBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAccentBar) ...[
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.accentForTheme(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelMedium.copyWith(
                letterSpacing: 1.0,
                fontSize: 13,
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
