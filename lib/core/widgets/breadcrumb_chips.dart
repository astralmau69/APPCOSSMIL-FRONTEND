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
            _chip(labels[i], i == labels.length - 1),
            if (i < labels.length - 1) _separator(),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: isLast
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLast
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
          color: AppColors.primary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _separator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: AppColors.textTertiary.withValues(alpha: 0.5),
      ),
    );
  }
}
