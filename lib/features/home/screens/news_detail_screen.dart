import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/news_item_model.dart';
import '../../../core/services/cossmil_news_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/image_enlarged_modal.dart';

class NewsDetailScreen extends StatefulWidget {
  final NewsItemModel item;

  const NewsDetailScreen({super.key, required this.item});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  List<String> _additionalImages = [];
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadAdditionalImages();
  }

  Future<void> _loadAdditionalImages() async {
    final images = await CossmilNewsService.fetchPublicationDetails(
      widget.item.gestion,
      widget.item.idpub,
    );
    if (!mounted) return;
    setState(() {
      _additionalImages = images;
      _isLoadingImages = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Comunicado'),
            backgroundColor: AppColors.navBarBg(isDark),
            previousPageTitle: 'Volver',
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Imagen Principal
                if (widget.item.imageUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () => ImageEnlargedModal.showFromUrl(
                      context: context,
                      url: widget.item.imageUrl,
                      fallbackText: 'I',
                    ),
                    child: Hero(
                      tag: 'news_img_${widget.item.idpub}',
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          widget.item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.all(r.paddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha y Entidad
                      Row(
                        children: [
                          if (widget.item.entity.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.item.entity,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            widget.item.date,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiaryC(isDark),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: r.spaceLg),
                      
                      // Título
                      FadeSlideIn(
                        offsetY: 20,
                        child: Text(
                          widget.item.title,
                          style: context.texts.headlineMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimaryC(isDark),
                            height: 1.2,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: r.spaceLg),
                      
                      // Descripción
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        offsetY: 10,
                        child: Text(
                          widget.item.description,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: AppColors.textSecondaryC(isDark),
                          ),
                        ),
                      ),

                      SizedBox(height: r.spaceXl),

                      // Galería de Imágenes Adicionales
                      if (_isLoadingImages)
                        const Center(child: CupertinoActivityIndicator())
                      else if (_additionalImages.isNotEmpty) ...[
                        Text(
                          'GALERÍA DE IMÁGENES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppColors.textTertiaryC(isDark),
                          ),
                        ),
                        SizedBox(height: r.spaceMd),
                        _buildGallery(r),
                      ],
                      
                      SizedBox(height: r.navBarBottomSpace + 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(AppResponsive r) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _additionalImages.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: r.spaceSm,
        mainAxisSpacing: r.spaceSm,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final url = _additionalImages[i];
        return GestureDetector(
          onTap: () => ImageEnlargedModal.showFromUrl(
            context: context,
            url: url,
            fallbackText: 'I',
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.radiusMd),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(CupertinoIcons.photo)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkElevated : const Color(0xFFF0F2F4),
      child: Icon(CupertinoIcons.photo, size: 48, color: AppColors.textTertiaryC(isDark)),
    );
  }
}
