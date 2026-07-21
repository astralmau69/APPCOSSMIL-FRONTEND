import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../tramite_catalog.dart';
import 'formularios_screen.dart';

/// Hub de procedimientos COSSMIL.
///
/// Agrupa los trámites por categoría. Hoy la única categoría es "Formularios"
/// (los documentos oficiales en PDF); nuevas categorías se agregan como más
/// tarjetas [_CategoryCard] en la lista.
class ProcedimientosScreen extends StatelessWidget {
  const ProcedimientosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          AdaptiveSliverNavBar(
            largeTitle: Text(
              'Procedimientos',
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
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              r.paddingH,
              12,
              r.paddingH,
              r.navBarBottomSpace,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeSlideIn(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: r.spaceLg),
                    child: _HeaderBanner(isDark: isDark, r: r),
                  ),
                ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: _CategoryCard(
                    icon: CupertinoIcons.doc_on_doc_fill,
                    color: const Color(0xFFD97706),
                    title: 'Formularios',
                    subtitle: 'Documentos oficiales en PDF y Word',
                    items: kTramites,
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => const FormulariosScreen(),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de la sección: presenta el propósito de "Procedimientos COSSMIL"
/// con un degradado institucional y una línea de apoyo.
class _HeaderBanner extends StatelessWidget {
  final bool isDark;
  final AppResponsive r;
  const _HeaderBanner({required this.isDark, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF10243A), const Color(0xFF0B1A2A)]
              : [const Color(0xFFEAF3FF), const Color(0xFFF3F8FF)],
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: const Color(0xFF005EB8).withValues(alpha: isDark ? 0.35 : 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: r.listAvatarSize,
            height: r.listAvatarSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF005EB8), Color(0xFF00457E)],
              ),
              borderRadius: BorderRadius.circular(r.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF005EB8).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(CupertinoIcons.doc_text_fill,
                size: r.iconMd, color: Colors.white),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trámites ante COSSMIL',
                  style: context.texts.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Text(
                  'Genera los documentos oficiales con tus datos ya cargados, '
                  'listos para imprimir, descargar o compartir.',
                  style: context.texts.bodySmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de categoría: cabecera con ícono, título y contador, más un índice
/// de su contenido (los trámites que agrupa). Toda la tarjeta es un único
/// destino táctil que abre el listado completo de la categoría.
class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<TramiteInfo> items;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;

    return Semantics(
      label: '$title: $subtitle. Contiene ${items.length} documentos.',
      hint: 'Toca para ver los formularios',
      button: true,
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.98,
        haptic: true,
        child: LiquidGlass(
          isDark: isDark,
          borderRadius: BorderRadius.circular(r.cardRadius),
          shadow: AppColors.cardShadowFor(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera de la categoría
              Padding(
                padding: EdgeInsets.all(r.cardPadding),
                child: Row(
                  children: [
                    Container(
                      width: r.listAvatarSize,
                      height: r.listAvatarSize,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: isDark ? 0.28 : 0.16),
                            color.withValues(alpha: isDark ? 0.16 : 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(r.radiusMd),
                      ),
                      child: Icon(icon, size: r.iconMd, color: color),
                    ),
                    SizedBox(width: r.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: texts.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryC(isDark),
                              letterSpacing: -0.2,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: r.spaceXs),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: texts.bodySmall.copyWith(
                              color: AppColors.textSecondaryC(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.spaceSm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(r.chipRadius),
                      ),
                      child: Text(
                        '${items.length}',
                        style: texts.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: r.spaceSm),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: r.iconSm * 0.7,
                      color: AppColors.textTertiaryC(isDark),
                    ),
                  ],
                ),
              ),
              Container(
                height: 0.5,
                color: AppColors.cardBorder(isDark).withValues(alpha: 0.7),
              ),
              // Índice del contenido: qué documentos viven dentro de la categoría
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: r.cardPadding,
                  vertical: r.spaceSm,
                ),
                child: Column(
                  children: [
                    for (final t in items)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: r.spaceXs),
                        child: Row(
                          children: [
                            Icon(t.icon, size: r.iconSm * 0.8, color: t.color),
                            SizedBox(width: r.spaceSm),
                            Expanded(
                              child: Text(
                                t.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: texts.bodySmall.copyWith(
                                  color: AppColors.textSecondaryC(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: r.spaceXs),
            ],
          ),
        ),
      ),
    );
  }
}
