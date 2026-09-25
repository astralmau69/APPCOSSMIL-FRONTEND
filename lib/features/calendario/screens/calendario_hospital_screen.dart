import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/data/app_session_cache.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/tutorial_flow.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/widgets/tutorial_flow_host.dart';
import 'specialty_selection_screen.dart';

class CalendarioHospitalScreen extends StatefulWidget {
  const CalendarioHospitalScreen({super.key});

  @override
  State<CalendarioHospitalScreen> createState() =>
      _CalendarioHospitalScreenState();
}

class _CalendarioHospitalScreenState extends State<CalendarioHospitalScreen> {
  final _service = ProgramacionService();

  List<HospitalModel> _hospitals = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // 0.2: Consumir caché de sesión si ya fue poblado por el orchestrator.
      // Solo hace HTTP si el caché está vacío (cold start o pull-to-refresh).
      final regionals =
          AppSessionCache.isLoaded && AppSessionCache.regionales.isNotEmpty
          ? AppSessionCache.regionales
          : await _service.getRegionalesPorDepartamento(1);
      AppLogger.info(
        'CalendarioHospitalScreen',
        'Regionales desde ${AppSessionCache.isLoaded ? "caché" : "API"}: ${regionals.length}',
      );

      // Sin filtro local: mostramos todos los establecimientos que devuelve
      // el servicio (el backend ya entrega solo los habilitados).
      final hospitals = <HospitalModel>[];
      for (final regional in regionals) {
        hospitals.addAll(regional.hospitals);
      }

      // Ordenar por idsuc numérico para que La Paz (1) siempre sea primero.
      hospitals.sort((a, b) {
        final ia = int.tryParse(a.id) ?? 99;
        final ib = int.tryParse(b.id) ?? 99;
        return ia.compareTo(ib);
      });

      if (mounted) {
        setState(() {
          _hospitals = hospitals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'.replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSelect(HospitalModel hospital) {
    final idsuc = int.tryParse(hospital.id) ?? 1;
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => SpecialtySelectionScreen(
          idsuc: idsuc,
          hospitalName: hospital.name,
          regionalName: hospital.city.isNotEmpty
              ? 'Regional ${hospital.city}'
              : hospital.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Calendario',
          style: TextStyle(
            color: AppColors.textPrimaryC(isDark),
            fontWeight: FontWeight.w600,
          ),
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
      child: SafeArea(
        // Paso 1 del tutorial del Calendario: la instructora presenta la
        // sección y pide elegir el establecimiento.
        child: TutorialFlowHost(
          tutorial: GuidedTutorial.calendario,
          step: 2,
          totalSteps: 5,
          voiceId: 'calendario_01',
          builder: (context, tutorialActive) =>
              _buildBody(isDark, r, tutorialActive),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, AppResponsive r, bool tutorialActive) {
    if (_isLoading) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          r.paddingH,
          r.spaceLg,
          r.paddingH,
          r.navBarBottomSpace,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoHeader(isDark, r),
            SizedBox(height: r.spaceLg),
            SkeletonRegionalList(count: 2),
          ],
        ),
      );
    }

    if (_error != null) {
      return AppStateWidget.error(
        title: 'No se pudo cargar los establecimientos',
        message: _error,
        onRetry: _load,
      );
    }

    if (_hospitals.isEmpty) {
      return const AppStateWidget.empty(
        title: 'Sin establecimientos disponibles',
        message: 'No hay hospitales habilitados en este momento.',
        icon: CupertinoIcons.building_2_fill,
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _load),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  r.paddingH,
                  r.spaceLg,
                  r.paddingH,
                  r.navBarBottomSpace,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Banner informativo ──────────────────────────────────
                    FadeSlideIn(
                      offsetY: 12,
                      child: _buildInfoHeader(isDark, r),
                    ),
                    SizedBox(height: r.spaceLg),

                    // ── Etiqueta de sección ─────────────────────────────────
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      offsetY: 8,
                      child: _buildSectionLabel(isDark, r),
                    ),
                    SizedBox(height: r.spaceSm),

                    // ── Cards de hospitales ─────────────────────────────────
                    ...List.generate(_hospitals.length, (i) {
                      final h = _hospitals[i];
                      // Color por sucursal: 1=azul (LPZ), 2=verde (CBBA), 3=naranja (SCZ), 11=rojo (TJA)
                      final color = switch (h.id) {
                        '1' => const Color(0xFF3B82F6),
                        '2' => const Color(0xFF10B981),
                        '3' => const Color(0xFFF59E0B),
                        '11' => const Color(0xFFEF4444),
                        _ => const Color(0xFF3B82F6),
                      };
                      final card = _HospitalCard(
                        hospital: h,
                        accentColor: color,
                        isDark: isDark,
                        onTap: () => _onSelect(h),
                      );
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 100 + i * 60),
                        offsetY: 10,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: r.spaceMd),
                          child: (tutorialActive && i == 0)
                              ? GuidedTapHint(child: card)
                              : card,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoHeader(bool isDark, AppResponsive r) {
    return Container(
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.7)
            : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(r.radiusMd),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentForTheme(isDark).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.radiusSm),
            ),
            child: Icon(
              CupertinoIcons.calendar,
              color: AppColors.accentForTheme(isDark),
              size: 20,
            ),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Horarios de Atención',
                  style: context.texts.titleMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Consulte los horarios de los médicos por establecimiento.',
                  style: context.texts.bodySmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(bool isDark, AppResponsive r) {
    return Row(
      children: [
        Container(
          width: r.sectionBarWidth,
          height: r.sectionBarHeight,
          decoration: BoxDecoration(
            color: AppColors.accentForTheme(isDark),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.spaceSm),
        Text(
          'SELECCIONE ESTABLECIMIENTO',
          style: context.texts.labelSmall.copyWith(
            color: AppColors.textTertiaryC(isDark),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─── Card individual de hospital ─────────────────────────────────────────────

class _HospitalCard extends StatelessWidget {
  final HospitalModel hospital;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _HospitalCard({
    required this.hospital,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final cardColor = AppColors.cardBg(isDark);
    // Ancho de la tira fotográfica — escala con el tamaño de pantalla
    final photoW = r.isSmallPhone
        ? 78.0
        : r.isTablet
        ? 128.0
        : 100.0;
    final hasPhoto = hospital.photoBase64.isNotEmpty;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r.cardRadius),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
            boxShadow: AppColors.cardShadowFor(isDark),
          ),
          child: Stack(
            children: [
              // ── Foto del hospital con sombreado (desvanecido en borde) ──
              if (hasPhoto)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: photoW,
                  child: _buildFadedHospitalPhoto(
                    hospital.photoBase64,
                    cardColor,
                  ),
                ),

              // ── Contenido — padding derecho reserva la zona de la foto ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.cardPadding,
                  r.cardPadding,
                  hasPhoto ? photoW + 8 : r.cardPadding,
                  r.cardPadding,
                ),
                child: Row(
                  children: [
                    // Ícono del hospital
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r.radiusMd),
                      ),
                      child: Icon(
                        CupertinoIcons.building_2_fill,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: r.spaceMd),

                    // Nombre + regional + dirección
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospital.name,
                            style: context.texts.titleMedium.copyWith(
                              color: AppColors.textPrimaryC(isDark),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hospital.city.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Regional ${hospital.city}',
                              style: context.texts.bodySmall.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (hospital.address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              hospital.address,
                              style: context.texts.bodySmall.copyWith(
                                color: AppColors.textTertiaryC(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(width: r.spaceSm),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: AppColors.textTertiaryC(isDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildFadedHospitalPhoto(String base64, Color cardColor) {
  try {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          base64Decode(base64),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
        // Desvanecido sutil en el borde izquierdo para fusionar con la card
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [cardColor, cardColor.withValues(alpha: 0.0)],
              stops: const [0.0, 0.45],
            ),
          ),
        ),
      ],
    );
  } catch (_) {
    return const SizedBox();
  }
}
