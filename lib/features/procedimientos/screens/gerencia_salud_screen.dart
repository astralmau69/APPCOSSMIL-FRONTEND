import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/tutorial_flow.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/tutorial_flow_host.dart';
import '../tramite_catalog.dart';
import 'formularios_screen.dart';

/// Nivel "Gerencia de Salud" dentro de Procedimientos COSSMIL.
///
/// Los trámites se organizan por gerencia (hub) → dependencia → documentos:
/// aquí se listan las dependencias de la Gerencia de Salud. Hoy la única es
/// "Hospital"; nuevas dependencias se agregan como más [GerenciaNavCard].
class GerenciaSaludScreen extends StatelessWidget {
  const GerenciaSaludScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Paso 2 del tutorial de Trámites: entrar a la dependencia Hospital.
      child: TutorialFlowHost(
        tutorial: GuidedTutorial.tramites,
        step: 3,
        totalSteps: 5,
        voiceId: 'tramites_02',
        messages: const [
          '¡Muy bien!',
          'Esta gerencia agrupa sus dependencias. Entra a "Hospital".',
        ],
        builder: (context, tutorialActive) {
          final hospitalCard = GerenciaNavCard(
            icon: CupertinoIcons.building_2_fill,
            color: const Color(0xFF005EB8),
            title: 'Hospital',
            subtitle: 'Trámites y formularios hospitalarios',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => const HospitalProcedimientosScreen(),
              ),
            ),
          );
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              AdaptiveSliverNavBar(
                largeTitle: Text(
                  'Gerencia de Salud',
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
                      child: tutorialActive
                          ? GuidedTapHint(child: hospitalCard)
                          : hospitalCard,
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Nivel "Hospital" dentro de la Gerencia de Salud: agrupa las categorías de
/// documentos hospitalarios. Hoy la única es "Formularios".
class HospitalProcedimientosScreen extends StatelessWidget {
  const HospitalProcedimientosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Paso 3 del tutorial de Trámites: abrir la categoría Formularios.
      child: TutorialFlowHost(
        tutorial: GuidedTutorial.tramites,
        step: 4,
        totalSteps: 5,
        voiceId: 'tramites_03',
        messages: const [
          'Ya casi llegamos.',
          'Cada categoría agrupa documentos. Abre "Formularios".',
        ],
        builder: (context, tutorialActive) {
          final formulariosCard = TramiteCategoryCard(
            icon: CupertinoIcons.doc_on_doc_fill,
            color: const Color(0xFFD97706),
            title: 'Formularios',
            subtitle: 'Documentos oficiales en PDF y Word',
            items: kTramites,
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const FormulariosScreen()),
            ),
          );
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              AdaptiveSliverNavBar(
                largeTitle: Text(
                  'Hospital',
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
                      child: tutorialActive
                          ? GuidedTapHint(child: formulariosCard)
                          : formulariosCard,
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta de categoría de documentos: cabecera con ícono, título y contador,
/// más un índice de su contenido (los trámites que agrupa). Toda la tarjeta es
/// un único destino táctil que abre el listado completo de la categoría.
class TramiteCategoryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<TramiteInfo> items;
  final VoidCallback onTap;

  const TramiteCategoryCard({
    super.key,
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

/// Tarjeta de navegación de un nivel jerárquico (gerencia o dependencia):
/// ícono en chip de color, título, subtítulo y chevron. Toda la tarjeta es un
/// único destino táctil.
class GerenciaNavCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const GerenciaNavCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final texts = context.texts;

    return Semantics(
      label: '$title: $subtitle',
      hint: 'Toca para ingresar',
      button: true,
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.98,
        haptic: true,
        child: LiquidGlass(
          isDark: isDark,
          borderRadius: BorderRadius.circular(r.cardRadius),
          padding: EdgeInsets.all(r.cardPadding),
          shadow: AppColors.cardShadowFor(isDark),
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
              Icon(
                CupertinoIcons.chevron_right,
                size: r.iconSm * 0.7,
                color: AppColors.textTertiaryC(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
