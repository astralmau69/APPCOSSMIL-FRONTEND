import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/news_item_model.dart';

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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _accentForImportance(widget.item.importance);

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: const Color(0xFF191C1E).withValues(alpha: isDark ? 0.3 : 0.15),
              width: 0.8,
            ),
            boxShadow: AppColors.cardShadowFor(isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Stack(
              children: [
                // Solid card background — no gradient
                Positioned.fill(
                  child: Container(
                    color: AppColors.cardBg(isDark),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Category Tag
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.item.category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                  letterSpacing: 0.8,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Date
                          Icon(CupertinoIcons.calendar, 
                            size: 12, color: AppColors.textTertiaryC(isDark)),
                          const SizedBox(width: 4),
                          Text(
                            widget.item.date,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiaryC(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryC(isDark),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Summary
                      Text(
                        widget.item.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryC(isDark),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Footer action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Leer más',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentForTheme(isDark),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 10,
                            color: AppColors.accentForTheme(isDark),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Importance indicator bar on top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 3,
                  child: Container(color: accentColor),
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
