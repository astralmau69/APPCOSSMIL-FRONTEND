import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/calendario_models.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/calendario_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/image_enlarged_modal.dart';

class DoctorScheduleScreen extends StatefulWidget {
  final MedicoSucModel doctor;
  final SpecialtyModel specialty;

  const DoctorScheduleScreen({
    super.key,
    required this.doctor,
    required this.specialty,
  });

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  final _service = CalendarioService();

  List<HorarioDia> _schedule = [];
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
      final list = await _service.getHorario(idMedico: widget.doctor.idmed);
      if (!mounted) return;
      setState(() {
        _schedule = list;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.transparent : AppColors.background,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Médicos',
        middle: Text(
          'Agenda Semanal',
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
        child: _buildBody(isDark, r),
      ),
    );
  }

  Widget _buildBody(bool isDark, AppResponsive r) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CupertinoActivityIndicator(radius: 14),
            SizedBox(height: r.spaceLg),
            Text(
              'Cargando horarios de atención...',
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
        title: 'No se pudo cargar la agenda',
        message: _error,
        onRetry: _load,
      );
    }

    if (_schedule.isEmpty) {
      return AppStateWidget.empty(
        title: 'Sin horarios registrados',
        message: '${widget.doctor.displayName} no tiene horarios de atención registrados.',
        icon: CupertinoIcons.calendar_badge_minus,
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceLg, r.paddingH, r.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDoctorBanner(isDark, r),
                    SizedBox(height: r.spaceLg),
                    ..._buildScheduleDays(isDark, r),
                    SizedBox(height: r.spaceXl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorBanner(bool isDark, AppResponsive r) {
    final photo = widget.doctor.photoBytes;
    final rBanner = r.cardRadius;
    return Container(
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.7)
            : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(rBanner),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: photo != null
                ? () {
                    ImageEnlargedModal.showFromBytes(
                      context: context,
                      bytes: photo,
                      fallbackText: widget.doctor.initials,
                    );
                  }
                : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: ClipOval(
                child: photo != null
                    ? Image.memory(photo, fit: BoxFit.cover, width: 64, height: 64)
                    : Center(
                        child: Text(
                          widget.doctor.initials,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.doctor.displayName,
                  style: context.texts.titleMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                Text(
                  widget.specialty.name,
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

  List<Widget> _buildScheduleDays(bool isDark, AppResponsive r) {
    List<Widget> items = [];
    for (int i = 0; i < _schedule.length; i++) {
      final dia = _schedule[i];
      items.add(
        FadeSlideIn(
          delay: Duration(milliseconds: 50 + (i * 40)),
          offsetY: 10,
          child: Padding(
            padding: EdgeInsets.only(bottom: r.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDayHeader(dia, isDark, r),
                SizedBox(height: r.spaceSm),
                _buildDaySlots(dia.slots, dia.consultorio, dia.piso, isDark, r),
              ],
            ),
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildDayHeader(HorarioDia dia, bool isDark, AppResponsive r) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.accentForTheme(isDark),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: r.spaceSm),
        Expanded(
          child: Text(
            dia.diaLabel.toUpperCase(),
            style: context.texts.labelSmall.copyWith(
              color: AppColors.textTertiaryC(isDark),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaySlots(
      List<HorarioMovilSlot> slots, String consultorio, String piso, bool isDark, AppResponsive r) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(r.cardRadius),
        border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
        boxShadow: AppColors.cardShadowFor(isDark),
      ),
      child: Column(
        children: [
          // Banner de Consultorio
          Container(
            padding: EdgeInsets.symmetric(horizontal: r.cardPadding, vertical: r.spaceSm),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(r.cardRadius - 1)),
              border: Border(bottom: BorderSide(color: AppColors.dividerC(isDark))),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.building_2_fill, size: 16, color: AppColors.textTertiaryC(isDark)),
                SizedBox(width: r.spaceSm),
                Text(
                  'Consultorio $consultorio',
                  style: context.texts.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
                if (piso.isNotEmpty) ...[
                  const Spacer(),
                  Text(
                    piso,
                    style: context.texts.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiaryC(isDark),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          ...List.generate(slots.length, (i) {
            final slot = slots[i];
            final isLast = i == slots.length - 1;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.cardPadding,
                    vertical: r.spaceMd,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 16,
                        color: AppColors.accentForTheme(isDark),
                      ),
                      SizedBox(width: r.spaceSm),
                      Text(
                        slot.rangoHorario,
                        style: context.texts.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryC(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.cardPadding),
                    child: Container(height: 0.5, color: AppColors.dividerC(isDark)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
