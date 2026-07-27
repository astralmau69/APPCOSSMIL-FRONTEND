import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Fila de breadcrumb chips scrollable — responsive.
class BreadcrumbChips extends StatelessWidget {
  final List<String> labels;

  const BreadcrumbChips({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.paddingH),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < labels.length; i++) ...[
              _chip(context, labels[i], i == labels.length - 1, r),
              if (i < labels.length - 1) _separator(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool isLast,
    AppResponsive r,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.accentForTheme(isDark);
    final fs = r.isSmallPhone ? 12.0 : 14.0;
    final pH = r.isSmallPhone ? 10.0 : 16.0;
    final pV = r.isSmallPhone ? 6.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: pH, vertical: pV),
      decoration: BoxDecoration(
        color: isLast
            ? primaryColor.withValues(alpha: 0.12)
            : primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(context.r.modalRadius),
        border: Border.all(
          color: isLast
              ? primaryColor.withValues(alpha: 0.3)
              : primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fs,
          fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
          color: primaryColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(
        Icons.chevron_right,
        size: 14,
        color: AppColors.textTertiaryC(
          Theme.of(context).brightness == Brightness.dark,
        ).withValues(alpha: 0.5),
      ),
    );
  }
}
