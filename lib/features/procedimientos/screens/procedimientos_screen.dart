import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/tutorial_flow.dart';
import '../../../core/widgets/adaptive_sliver_nav_bar.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/tutorial_flow_host.dart';
import 'gerencia_salud_screen.dart';

/// Hub de procedimientos COSSMIL.
///
/// Los trámites se organizan POR GERENCIA, reflejando la estructura
/// institucional: gerencia → dependencia → documentos (p. ej. Gerencia de
/// Salud → Hospital → Formularios). Nuevas gerencias se agregan como más
/// tarjetas [GerenciaNavCard] en la lista.
class ProcedimientosScreen extends StatelessWidget {
  const ProcedimientosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Paso 1 del tutorial de Trámites. Este hub es la raíz del recorrido:
      // si el usuario lo abandona con "atrás", el tutorial se cancela solo
      // (stopOnDispose).
      child: TutorialFlowHost(
        tutorial: GuidedTutorial.tramites,
        step: 2,
        totalSteps: 5,
        voiceId: 'tramites_01',
        stopOnDispose: true,
        builder: (context, tutorialActive) {
          final gerenciaCard = GerenciaNavCard(
            icon: CupertinoIcons.heart_circle_fill,
            color: const Color(0xFF059669),
            title: 'Gerencia de Salud',
            subtitle: 'Hospital y servicios de salud',
            onTap: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const GerenciaSaludScreen()),
            ),
          );
          return CustomScrollView(
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
                      delay: const Duration(milliseconds: 60),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: r.spaceMd),
                        child: const SectionHeader(text: 'POR GERENCIA'),
                      ),
                    ),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 100),
                      child: tutorialActive
                          ? GuidedTapHint(child: gerenciaCard)
                          : gerenciaCard,
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
          color: const Color(
            0xFF005EB8,
          ).withValues(alpha: isDark ? 0.35 : 0.18),
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
            child: Icon(
              CupertinoIcons.doc_text_fill,
              size: r.iconMd,
              color: Colors.white,
            ),
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
