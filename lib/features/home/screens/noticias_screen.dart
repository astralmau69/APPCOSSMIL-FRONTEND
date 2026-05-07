import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/services/cossmil_news_service.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/utils/error_mapper.dart';
import 'news_detail_screen.dart';

/// Pantalla dedicada para comunicados y noticias de COSSMIL con paginación.
class NoticiasScreen extends StatefulWidget {
  const NoticiasScreen({super.key});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  final List<NewsItemModel> _news = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final result = await CossmilNewsService.fetchPage(page: 1, perPage: 15);
      if (!mounted) return;
      setState(() {
        _news.clear();
        _news.addAll(result.items);
        _totalPages = result.totalPages;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = ErrorMapper.message(e); _isLoading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _totalPages) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await CossmilNewsService.fetchPage(page: nextPage, perPage: 15);
      if (!mounted) return;
      setState(() {
        _news.addAll(result.items);
        _currentPage = nextPage;
        _totalPages = result.totalPages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(
              'COSSMIL te informa',
              style: TextStyle(color: AppColors.textPrimaryC(isDark)),
            ),
            backgroundColor: AppColors.navBarBg(isDark),
            border: Border(
              bottom: BorderSide(
                color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: _load),

          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator(radius: 14)),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState(isDark),
            )
          else if (_news.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(isDark),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.r.paddingH, 12, context.r.paddingH, 0),
              sliver: SliverList.builder(
                itemCount: _news.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _news.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CupertinoActivityIndicator()),
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.r.spaceMd),
                    child: FadeSlideIn(
                      delay: Duration(milliseconds: i < 10 ? i * 60 : 0),
                      child: _NewsListCard(
                        item: _news[i],
                        onTap: () => _showDetail(_news[i]),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Indicador de página
            SliverPadding(
              padding: EdgeInsets.fromLTRB(context.r.paddingH, 8, context.r.paddingH, context.r.navBarBottomSpace),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    'Página $_currentPage de $_totalPages',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiaryC(isDark),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.r.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.wifi_slash,
                size: context.r.iconLg, color: AppColors.textTertiaryC(isDark)),
            SizedBox(height: context.r.spaceMd),
            Text(
              'No se pudo cargar los comunicados',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryC(isDark),
              ),
            ),
            SizedBox(height: context.r.spaceSm),
            Text(
              'Verifica tu conexión y desliza hacia abajo para reintentar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryC(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(context.r.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.news,
            size: context.r.emptyIconSize,
            color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.5),
          ),
          SizedBox(height: context.r.spaceLg),
          Text(
            'Sin comunicados recientes',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryC(isDark),
            ),
          ),
          SizedBox(height: context.r.spaceSm),
          Text(
            'Te notificaremos cuando haya nuevos avisos importantes de COSSMIL.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(NewsItemModel item) {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => NewsDetailScreen(item: item),
      ),
    );
  }
}

/// Card compacta para la lista de noticias — muestra fecha, título y entidad.
class _NewsListCard extends StatelessWidget {
  final NewsItemModel item;
  final VoidCallback? onTap;

  const _NewsListCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.r.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.cardBg(isDark),
          borderRadius: BorderRadius.circular(context.r.radiusMd),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFF191C1E).withValues(alpha: 0.08),
            width: isDark ? 0.8 : 0.5,
          ),
          boxShadow: AppColors.cardShadowFor(isDark),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen thumbnail (si existe)
            if (item.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(context.r.radiusSm),
                child: Image.network(
                  item.imageUrl,
                  width: context.r.avatarMd,
                  height: context.r.avatarMd,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: context.r.avatarMd,
                    height: context.r.avatarMd,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkElevated : AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(context.r.radiusSm),
                    ),
                    child: Icon(
                      CupertinoIcons.news,
                      size: 22,
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.r.spaceMd),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryC(isDark),
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: context.r.spaceSm),
                  // Entidad + fecha
                  Row(
                    children: [
                      if (item.entity.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            item.entity,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiaryC(isDark),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.r.spaceSm),
                          child: Text(
                            '·',
                            style: TextStyle(
                              color: AppColors.textTertiaryC(isDark),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        item.date,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiaryC(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: context.r.spaceSm),
            Padding(
              padding: EdgeInsets.only(top: context.r.spaceXs),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.textTertiaryC(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
