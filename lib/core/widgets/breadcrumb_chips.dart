import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Paleta de colores centralizada — COSSMIL App.
/// Azul institucional + verde médico + acentos dorados.

/// Fila de breadcrumb chips scrollable.
class BreadcrumbChips extends StatelessWidget {
  final List<String> labels;

  const BreadcrumbChips({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 6,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            _chip(context, labels[i], i == labels.length - 1),
            if (i < labels.length - 1) _separator(context),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, bool isLast) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.accentForTheme(isDark);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isLast
            ? primaryColor.withValues(alpha: 0.12)
            : primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLast
              ? primaryColor.withValues(alpha: 0.3)
              : primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
          color: primaryColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _separator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: AppColors.textTertiaryC(Theme.of(context).brightness == Brightness.dark).withValues(alpha: 0.5),
      ),
    );
  }
}
