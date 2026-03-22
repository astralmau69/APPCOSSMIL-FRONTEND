import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/news_item_model.dart';

/// Card reutilizable para comunicados institucionales.
/// Muestra fecha, categoría, título y resumen con jerarquía visual.
/// Incluye feedback táctil animado (scale down on press).
class NewsCard extends StatefulWidget {
  final NewsItemModel item;
  final VoidCallback? onTap;

  const NewsCard({super.key, required this.item, this.onTap});

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentForImportance(widget.item.importance);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: RepaintBoundary(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: widget.item.importance == NewsImportance.critical
                    ? AppColors.error.withValues(alpha: 0.25)
                    : AppColors.border,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                      widget.item.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    widget.item.date,
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
                widget.item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              // Summary
              Text(
                widget.item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
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
