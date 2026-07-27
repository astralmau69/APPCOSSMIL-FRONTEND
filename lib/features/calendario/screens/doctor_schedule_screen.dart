import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/calendario_models.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/calendario_service.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/services/tutorial_flow.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/image_enlarged_modal.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/tutorial_flow_host.dart';

// ─── Modelo de turno ─────────────────────────────────────────────────────────

enum _Turno { manana, tarde, noche }

extension _TurnoExt on _Turno {
  String get label => switch (this) {
    _Turno.manana => 'Mañana',
    _Turno.tarde => 'Tarde',
    _Turno.noche => 'Noche',
  };

  IconData get icon => switch (this) {
    _Turno.manana => CupertinoIcons.sunrise_fill,
    _Turno.tarde => CupertinoIcons.sun_max_fill,
    _Turno.noche => CupertinoIcons.moon_stars_fill,
  };

  Color get color => switch (this) {
    _Turno.manana => const Color(0xFFF59E0B), // ámbar
    _Turno.tarde => const Color(0xFFEF7C34), // naranja
    _Turno.noche => const Color(0xFF6366F1), // índigo
  };

  Color get bgLight => switch (this) {
    _Turno.manana => const Color(0xFFFFFBEB),
    _Turno.tarde => const Color(0xFFFFF3E0),
    _Turno.noche => const Color(0xFFEEF2FF),
  };

  Color get bgDark => switch (this) {
    _Turno.manana => const Color(0xFF2D2207),
    _Turno.tarde => const Color(0xFF2D1800),
    _Turno.noche => const Color(0xFF1E1B40),
  };

  Color bg(bool isDark) => isDark ? bgDark : bgLight;

  /// 06:00-11:59 → Mañana / 12:00-17:59 → Tarde / 18:00+ → Noche
  static _Turno fromHora(String hora) {
    final parts = hora.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    if (h < 12) return _Turno.manana;
    if (h < 18) return _Turno.tarde;
    return _Turno.noche;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class DoctorScheduleScreen extends StatefulWidget {
  final MedicoSucModel doctor;
  final SpecialtyModel specialty;
  final int idsuc;

  const DoctorScheduleScreen({
    super.key,
    required this.doctor,
    required this.specialty,
    required this.idsuc,
  });

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  late final CalendarioService _service;

  List<HorarioDia> _schedule = [];
  bool _isLoading = true;
  String? _error;

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
        previousPageTitle: widget.specialty.name,
        middle: Text(
          'Agenda',
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
        // Paso final del tutorial del Calendario: la instructora celebra y
        // explica cómo leer la agenda. Salir aquí ya no pide confirmación.
        child: TutorialFlowHost(
          tutorial: GuidedTutorial.calendario,
          step: 5,
          totalSteps: 5,
          voiceId: 'calendario_04',
          celebrate: true,
          confirmOnExit: false,
          messages: const [
            '¡Eso es todo! 🎖️',
            'Aquí ves los días, turnos y horas en que atiende este médico. '
                'Recuerda: esto es solo consulta — para sacar una ficha usa '
                '"Nueva Reserva" en Inicio. Puedes repetir este tutorial '
                'desde tu Perfil.',
          ],
          builder: (context, _) => _buildBody(isDark, r),
        ),
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
        message:
            '${widget.doctor.displayName} no tiene horarios de atención registrados.',
        icon: CupertinoIcons.calendar_badge_minus,
      );
    }

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
                    _buildDoctorBanner(isDark, r),
                    SizedBox(height: r.spaceLg),
                    _buildLegend(isDark, r),
                    SizedBox(height: r.spaceLg),
                    ..._buildScheduleDays(isDark, r),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Banner del médico ─────────────────────────────────────────────────────

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
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: ClipOval(
                child: photo != null
                    ? Image.memory(
                        photo,
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                      )
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

  // ── Leyenda de turnos ─────────────────────────────────────────────────────

  Widget _buildLegend(bool isDark, AppResponsive r) {
    final turnos = [_Turno.manana, _Turno.tarde, _Turno.noche];
    return Row(
      children: turnos.map((t) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: t == _Turno.noche ? 0 : r.spaceSm),
            padding: EdgeInsets.symmetric(
              horizontal: r.spaceSm,
              vertical: r.spaceSm - 2,
            ),
            decoration: BoxDecoration(
              color: t.bg(isDark),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: t.color.withValues(alpha: isDark ? 0.3 : 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, size: 13, color: t.color),
                const SizedBox(width: 5),
                Text(
                  t.label,
                  style: context.texts.labelSmall.copyWith(
                    color: t.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Días de la semana ─────────────────────────────────────────────────────

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
                _buildDayCard(dia, isDark, r),
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

  // ── Card del día con agrupaciones por turno ───────────────────────────────

  Widget _buildDayCard(HorarioDia dia, bool isDark, AppResponsive r) {
    // Agrupar slots por turno (Mañana / Tarde / Noche)
    final Map<_Turno, List<HorarioMovilSlot>> byTurno = {};
    for (final slot in dia.slots) {
      final turno = _TurnoExt.fromHora(slot.horaini);
      byTurno.putIfAbsent(turno, () => []).add(slot);
    }

    // Orden canónico de turnos
    final turnosPresentes = [
      _Turno.manana,
      _Turno.tarde,
      _Turno.noche,
    ].where((t) => byTurno.containsKey(t)).toList();

    return LiquidGlass(
      isDark: isDark,
      borderRadius: BorderRadius.circular(r.cardRadius),
      shadow: AppColors.cardShadowFor(isDark),
      child: Column(
        children: [
          // Encabezado con Consultorio y Piso
          _buildConsultorioBanner(dia.consultorio, dia.piso, isDark, r),

          // Secciones por turno
          ...List.generate(turnosPresentes.length, (ti) {
            final turno = turnosPresentes[ti];
            final slots = byTurno[turno]!;
            final isLastSection = ti == turnosPresentes.length - 1;
            return _buildTurnoSection(turno, slots, isDark, r, isLastSection);
          }),
        ],
      ),
    );
  }

  Widget _buildConsultorioBanner(
    String consultorio,
    String piso,
    bool isDark,
    AppResponsive r,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.cardPadding,
        vertical: r.spaceSm,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2D35) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(r.cardRadius - 1),
        ),
        border: Border(bottom: BorderSide(color: AppColors.dividerC(isDark))),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.building_2_fill,
            size: 16,
            color: AppColors.textTertiaryC(isDark),
          ),
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
    );
  }

  Widget _buildTurnoSection(
    _Turno turno,
    List<HorarioMovilSlot> slots,
    bool isDark,
    AppResponsive r,
    bool isLastSection,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado del turno
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.cardPadding,
            vertical: r.spaceSm - 2,
          ),
          decoration: BoxDecoration(
            color: turno.bg(isDark),
            border: Border(
              bottom: BorderSide(
                color: turno.color.withValues(alpha: isDark ? 0.2 : 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(turno.icon, size: 14, color: turno.color),
              SizedBox(width: r.spaceSm),
              Text(
                turno.label,
                style: context.texts.labelSmall.copyWith(
                  color: turno.color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: turno.color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${slots.length} ${slots.length == 1 ? 'bloque' : 'bloques'}',
                  style: context.texts.labelSmall.copyWith(
                    color: turno.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Slots del turno
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
                      color: turno.color.withValues(
                        alpha: isDark ? 0.85 : 0.75,
                      ),
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
                  child: Container(
                    height: 0.5,
                    color: AppColors.dividerC(isDark),
                  ),
                ),
            ],
          );
        }),

        // Separador entre secciones de turno (si no es la última)
        if (!isLastSection)
          Container(height: 1, color: AppColors.cardBorder(isDark)),
      ],
    );
  }
}
