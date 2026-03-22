import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_news_data.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/widgets/news_card.dart';
import '../../../core/animations/optimized_animations.dart';

/// Pantalla dedicada para comunicados, noticias y avisos institucionales.
class NoticiasScreen extends StatelessWidget {
  const NoticiasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final allNews = MockNewsData.news;
    final featured = allNews.where((n) => n.isFeatured).toList();
    final regular = allNews.where((n) => !n.isFeatured).toList();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('COSSMIL te informa'),
            backgroundColor: AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.border.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Subtitle
                  const FadeSlideIn(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Comunicados, avisos y anuncios importantes para nuestros asegurados.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),

                  // ── Featured / Destacados ───────────────────────
                  if (featured.isNotEmpty) ...[
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: _sectionHeader('DESTACADOS', featured.length),
                    ),
                    const SizedBox(height: 10),
                    for (int i = 0; i < featured.length; i++) ...[
                      FadeSlideIn(
                        delay: Duration(milliseconds: 120 + i * 80),
                        child: _FeaturedCard(item: featured[i]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // ── All news chronological header ───────────────
                  FadeSlideIn(
                    delay: Duration(milliseconds: 200 + featured.length * 80),
                    child: _sectionHeader('TODOS LOS COMUNICADOS', allNews.length),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList.builder(
              itemCount: regular.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: i < regular.length - 1 ? 10 : 24),
                  child: FadeSlideIn(
                    delay: Duration(milliseconds: 240 + featured.length * 80 + i * 60),
                    child: NewsCard(item: regular[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionHeader(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card destacada con gradiente lateral y badge visual.
class _FeaturedCard extends StatelessWidget {
  final NewsItemModel item;
  const _FeaturedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (item.importance) {
      NewsImportance.critical => AppColors.error,
      NewsImportance.warning => AppColors.warning,
      NewsImportance.normal => AppColors.info,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
        border: Border.all(
          color: accentColor.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 5,
            height: 120,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                bottomLeft: Radius.circular(AppTheme.radiusLg),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: badge + date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.importance == NewsImportance.critical
                                  ? CupertinoIcons.exclamationmark_triangle_fill
                                  : CupertinoIcons.star_fill,
                              size: 10,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.date,
                        style: const TextStyle(
                          fontSize: 11,
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
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Summary
                  Text(
                    item.summary,
                    maxLines: 2,
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
          ),
        ],
      ),
    );
  }
}
