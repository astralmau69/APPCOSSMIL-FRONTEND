import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Widget reutilizable para cabeceras de sección con estilo consistente.
///
/// Muestra una barra de acento vertical + texto uppercase con tracking.
class SectionHeader extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;
  final bool showAccentBar;

  const SectionHeader({
    super.key,
    required this.text,
    this.padding,
    this.showAccentBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return Padding(
      padding: padding ?? EdgeInsets.only(left: r.paddingH),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAccentBar) ...[
            Container(
              width: r.sectionBarWidth,
              height: r.sectionBarHeight,
              decoration: BoxDecoration(
                color: AppColors.accentForTheme(isDark),
                borderRadius: BorderRadius.circular(context.r.spaceXs),
              ),
            ),
            SizedBox(width: r.spaceSm),
          ],
          Flexible(
            child: Text(
              text,
              style: context.texts.labelSmall.copyWith(
                letterSpacing: 1.0,
                fontSize: r.sectionLabelSize,
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
