import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/calendario_models.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/calendario_service.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/tutorial_flow.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/tutorial_flow_host.dart';
import 'doctor_schedule_screen.dart';

class DoctorSelectionScreen extends StatefulWidget {
  final SpecialtyModel specialty;
  final int idsuc;
  final String hospitalName;
  final String regionalName;

  const DoctorSelectionScreen({
    super.key,
    required this.specialty,
    required this.idsuc,
    required this.hospitalName,
    required this.regionalName,
  });

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  late final CalendarioService _service;

  List<MedicoSucModel> _doctors = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = CalendarioService(idsuc: widget.idsuc);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final idesp = int.tryParse(widget.specialty.id) ?? 0;
      final list = await _service.getMedicos(
        idesp: idesp,
        especialidadNombre: widget.specialty.name,
      );
      if (!mounted) return;
      setState(() {
        _doctors = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onTap(MedicoSucModel doctor) {
    Navigator.of(context).push(
      AppPageRoute(
        builder: (_) => DoctorScheduleScreen(
          doctor: doctor,
          specialty: widget.specialty,
          idsuc: widget.idsuc,
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
        previousPageTitle: 'Especialidades',
        middle: Text(
          widget.specialty.name,
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
        // Paso 3 del tutorial del Calendario: elegir el médico.
        child: TutorialFlowHost(
          tutorial: GuidedTutorial.calendario,
          step: 4,
          totalSteps: 5,
          voiceId: 'calendario_03',
          messages: const [
            'Estos son los médicos de esa especialidad.',
            'Toca uno para ver su horario de atención.',
          ],
          builder: (context, tutorialActive) =>
              _buildBody(isDark, r, tutorialActive),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, AppResponsive r, bool tutorialActive) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            SizedBox(height: r.spaceLg),
            Text(
              'Cargando médicos disponibles...',
              style: TextStyle(
                color: AppColors.textSecondaryC(isDark),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return AppStateWidget.error(
        title: 'No se pudieron cargar los médicos',
        message: _error,
        onRetry: _load,
      );
    }

    if (_doctors.isEmpty) {
      return AppStateWidget.empty(
        title: 'Sin médicos disponibles',
        message:
            'No hay médicos atendiendo ${widget.specialty.name} actualmente.',
        icon: CupertinoIcons.person_2_alt,
      );
    }

    final filteredDoctors = _searchQuery.isEmpty
        ? _doctors
        : _doctors
              .where(
                (d) =>
                    d.nombre.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    d.consultorio.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
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
                    Padding(
                      padding: EdgeInsets.only(bottom: r.spaceLg),
                      child: CupertinoSearchTextField(
                        placeholder: 'Buscar por nombre o consultorio...',
                        style: TextStyle(color: AppColors.textPrimaryC(isDark)),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    _buildSectionHeader(isDark, r, filteredDoctors.length),
                    SizedBox(height: r.spaceSm),
                    _buildDoctorsList(
                      isDark,
                      r,
                      filteredDoctors,
                      highlightFirst: tutorialActive,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(bool isDark, AppResponsive r, int count) {
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
        Expanded(
          child: Text(
            'MÉDICOS EN ATENCIÓN',
            style: context.texts.labelSmall.copyWith(
              color: AppColors.textTertiaryC(isDark),
              letterSpacing: 0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: context.texts.labelSmall.copyWith(
            color: AppColors.accentForTheme(isDark),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorsList(
    bool isDark,
    AppResponsive r,
    List<MedicoSucModel> doctors, {
    bool highlightFirst = false,
  }) {
    if (doctors.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: r.spaceXl),
        child: Center(
          child: Text(
            'Ningún médico coincide con la búsqueda.',
            style: TextStyle(color: AppColors.textTertiaryC(isDark)),
          ),
        ),
      );
    }
    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      shadow: AppColors.cardShadowFor(isDark),
      child: Column(
        children: List.generate(doctors.length, (i) {
          final doc = doctors[i];
          final isLast = i == doctors.length - 1;
          final tile = CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _onTap(doc),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: r.tileHorizontalPad,
                vertical: r.tileVerticalPad,
              ),
              child: Row(
                children: [
                  _buildAvatar(doc, isDark, r),
                  SizedBox(width: r.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.displayName,
                          style: context.texts.titleMedium.copyWith(
                            color: AppColors.textPrimaryC(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: r.spaceSm),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: AppColors.textTertiaryC(isDark),
                  ),
                ],
              ),
            ),
          );
          return FadeSlideIn(
            delay: Duration(milliseconds: i * 40),
            offsetY: 8,
            child: Column(
              children: [
                (highlightFirst && i == 0) ? GuidedTapHint(child: tile) : tile,
                if (!isLast)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.cardPadding),
                    child: Container(
                      height: 0.5,
                      color: AppColors.dividerC(isDark),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAvatar(MedicoSucModel doc, bool isDark, AppResponsive r) {
    final photo = doc.photoBytes;
    final radius = 32.0;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: photo != null
            ? Image.memory(
                photo,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
              )
            : Center(
                child: Text(
                  doc.initials,
                  style: TextStyle(
                    fontSize: radius * 0.9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}
