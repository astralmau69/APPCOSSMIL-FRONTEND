import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Fila de breadcrumb chips scrollable.
class BreadcrumbChips extends StatelessWidget {
  final List<String> labels;

  const BreadcrumbChips({super.key, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isLast
            ? AppColors.primary.withOpacity(0.12)
            : AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLast
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
          color: AppColors.primary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _separator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        Icons.chevron_right,
        size: 12,
        color: AppColors.textTertiary.withOpacity(0.5),
      ),
    );
  }
}
