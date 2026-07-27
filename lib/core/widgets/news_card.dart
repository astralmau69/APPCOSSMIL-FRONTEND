import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../theme/app_theme.dart';
import '../models/news_item_model.dart';

/// Card de noticia reutilizable — muestra título, descripción, entidad y fecha.
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
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFF191C1E).withValues(alpha: 0.12),
              width: isDark ? 0.8 : 0.5,
            ),
            boxShadow: AppColors.cardShadowFor(isDark),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.item.entity.isNotEmpty) ...[
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.r.spaceSm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              context.r.badgeRadius,
                            ),
                          ),
                          child: Text(
                            widget.item.entity,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(width: context.r.spaceSm),
                    ],
                    Icon(
                      CupertinoIcons.calendar,
                      size: 12,
                      color: AppColors.textTertiaryC(isDark),
                    ),
                    SizedBox(width: context.r.spaceXs),
                    Text(
                      widget.item.date,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiaryC(isDark),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.r.spaceMd),
                Text(
                  widget.item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    height: 1.2,
                  ),
                ),
                SizedBox(height: context.r.spaceSm),
                Text(
                  widget.item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: context.r.spaceMd),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Leer más',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentForTheme(isDark),
                      ),
                    ),
                    SizedBox(width: context.r.spaceXs),
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
        ),
      ),
    );
  }
}
