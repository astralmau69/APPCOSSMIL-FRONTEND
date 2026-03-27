import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/services/cossmil_news_service.dart';
import '../../../core/widgets/news_card.dart';
import '../../../core/animations/optimized_animations.dart';

/// Pantalla dedicada para comunicados, noticias y avisos institucionales.
/// Carga datos desde [CossmilNewsService] con fallback a mock data.
class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  List<NewsItemModel> _news = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final items = await CossmilNewsService.fetchComunicados();
      if (!mounted) return;
      setState(() { _news = items; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final featured = _news.where((n) => n.isFeatured).toList();
    final regular = _news.where((n) => !n.isFeatured).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'COSSMIL te informa',
              style: TextStyle(color: AppColors.textPrimaryC(isDark)),
            ),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          CupertinoSliverRefreshControl(onRefresh: _load),

          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.wifi_slash,
                          size: 40, color: AppColors.textTertiaryC(isDark)),
                      const SizedBox(height: 16),
                      Text(
                        'No se pudo cargar los comunicados',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryC(isDark),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verifica tu conexión y desliza hacia abajo para reintentar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryC(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_news.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.news,
                      size: 60,
                      color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sin comunicados recientes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Te notificaremos cuando haya nuevos avisos importantes de COSSMIL.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (featured.isNotEmpty) ...[
                      _sectionHeader(context, 'DESTACADOS', featured.length),
                      const SizedBox(height: 12),
                      for (int i = 0; i < featured.length; i++) ...[
                        FadeSlideIn(
                          delay: Duration(milliseconds: 100 + i * 100),
                          child: NewsCard(item: featured[i]),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),
                    ],

                    _sectionHeader(
                        context, 'ÚLTIMOS COMUNICADOS', regular.length),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList.builder(
                itemCount: regular.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FadeSlideIn(
                    delay: Duration(
                        milliseconds: 200 + featured.length * 100 + i * 80),
                    child: NewsCard(item: regular[i]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _sectionHeader(BuildContext context, String text, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.accentForTheme(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryC(isDark),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card destacada con barra lateral de color semántico.
class _FeaturedCard extends StatelessWidget {
  final NewsItemModel item;
  const _FeaturedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = switch (item.importance) {
      NewsImportance.critical => AppColors.error,
      NewsImportance.warning  => AppColors.warning,
      NewsImportance.normal   => AppColors.info,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
          color: isDark
              ? AppColors.cardBorder(isDark)
              : accentColor.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          // Barra lateral de color semántico
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                  ? CupertinoIcons
                                      .exclamationmark_triangle_fill
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiaryC(isDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryC(isDark),
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
