import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../tramite_catalog.dart';
import 'tramite_form_screen.dart';

/// Listado de formularios oficiales de COSSMIL.
///
/// Cada tarjeta abre un formulario que autocompleta los datos del solicitante
/// y genera el documento oficial en PDF, listo para previsualizar, imprimir o
/// compartir.
class FormulariosScreen extends StatelessWidget {
  const FormulariosScreen({super.key});

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
              'Formularios',
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
                    child: _IntroBanner(isDark: isDark, r: r),
                  ),
                ),
                for (int i = 0; i < kTramites.length; i++) ...[
                  FadeSlideIn(
                    delay: Duration(milliseconds: 80 + i * 70),
                    child: _TramiteCard(info: kTramites[i]),
                  ),
                  SizedBox(height: r.spaceMd),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner de cabecera: da contexto oficial a la sección y refuerza la confianza
/// (sello verificado + copy sobre el autocompletado).
class _IntroBanner extends StatelessWidget {
  final bool isDark;
  final AppResponsive r;
  const _IntroBanner({required this.isDark, required this.r});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0C2A22), const Color(0xFF0A1C24)]
              : [const Color(0xFFF0FBF6), const Color(0xFFEAF5FF)],
        ),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(
          color: const Color(0xFF059669).withValues(alpha: isDark ? 0.35 : 0.20),
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
                colors: [Color(0xFF059669), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(r.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(CupertinoIcons.checkmark_seal_fill,
                size: r.iconMd, color: Colors.white),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documentos oficiales COSSMIL',
                  style: context.texts.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Text(
                  'Autocompletamos tu nombre y cédula; solo revisa, '
                  'previsualiza e imprime, comparte o descarga en PDF o Word.',
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

class _TramiteCard extends StatelessWidget {
  final TramiteInfo info;
  const _TramiteCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return OptimizedPressButton(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => TramiteFormScreen(info: info)),
      ),
      scaleDown: 0.98,
      haptic: true,
      child: LiquidGlass(
        isDark: isDark,
        borderRadius: BorderRadius.circular(r.cardRadius),
        padding: EdgeInsets.all(r.cardPadding),
        shadow: AppColors.cardShadowFor(isDark),
        child: Row(
            children: [
              // Chip de ícono con degradado tenue
              Container(
                width: r.listAvatarSize,
                height: r.listAvatarSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      info.color.withValues(alpha: isDark ? 0.28 : 0.16),
                      info.color.withValues(alpha: isDark ? 0.16 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(r.radiusMd),
                ),
                child: Icon(info.icon, size: r.iconMd, color: info.color),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.titulo,
                      style: context.texts.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: r.spaceXs),
                    Text(
                      info.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: r.spaceSm),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(r.chipRadius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.doc_text_fill,
                                  size: 11, color: info.color),
                              const SizedBox(width: 4),
                              Text(
                                'PDF · Word',
                                style: context.texts.labelSmall.copyWith(
                                  color: info.color,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.spaceXs),
              Icon(
                CupertinoIcons.chevron_right,
                size: r.iconSm * 0.7,
                color: AppColors.textTertiaryC(isDark),
              ),
            ],
          ),
      ),
    );
  }
}
