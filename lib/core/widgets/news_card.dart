import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/news_item_model.dart';

/// Card reutilizable para comunicados institucionales.
/// Muestra fecha, categoría, título y resumen con jerarquía visual.
class NewsCard extends StatelessWidget {
  final NewsItemModel item;
  final VoidCallback? onTap;

  const NewsCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentForImportance(item.importance);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppColors.softShadow,
          border: item.importance == NewsImportance.critical
              ? Border.all(
                  color: AppColors.error.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: category badge + date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  item.date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            // Summary
            Text(
              item.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accentForImportance(NewsImportance importance) {
    switch (importance) {
      case NewsImportance.critical:
        return AppColors.error;
      case NewsImportance.warning:
        return AppColors.warning;
      case NewsImportance.normal:
        return AppColors.info;
    }
  }
}
