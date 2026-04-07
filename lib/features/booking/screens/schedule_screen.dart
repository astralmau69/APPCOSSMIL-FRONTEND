import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/time_slot_model.dart';
import '../../../core/models/medico_asignado_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/booking_stepper.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/utils/error_mapper.dart';
import 'summary_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final TabShellState tabShell;

  const ScheduleScreen({super.key, required this.tabShell});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  final _service = ProgramacionService();

  MedicoAsignadoModel? _medicoAsignado;
  List<TimeSlotModel> _slots = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorTitle;

  Timer? _refreshTimer;
  static const _refreshInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _fetchData();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Eliminamos _getFecha local porque ahora dependemos de getFechaServidor

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bs = widget.tabShell.bookingState;
      final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
      final idesp = int.tryParse(bs.specialty?.id ?? '') ?? 0;
      const modalidad = 'ASE';

      // 1. Obtener la fecha indicada por el servidor
      final fechaData = await _service.getFechaServidor();
      final fechaCitaMovil = fechaData['fechaCitaMovil'] ?? '';

      if (fechaCitaMovil.isEmpty) {
        throw Exception('No se pudo obtener la fecha de cita del servidor');
      }

      debugPrint('🌐 Consultando medico-asignado: idsuc=$idsuc, idesp=$idesp, fecha=$fechaCitaMovil, mod=$modalidad');

      try {
        _medicoAsignado = await _service.getMedicoAsignado(
          1, idsuc, idesp, fechaCitaMovil, modalidad,
        );
        _slots = _medicoAsignado!.toTimeSlots();
      } catch (e) {
        debugPrint('⚠️ Falló consulta para la fecha del servidor: $e');
        _medicoAsignado = null;
        _slots = [];
      }

      if (!mounted) return;

      debugPrint('📋 Medico asignado: ${_medicoAsignado?.medico}');
      debugPrint('🕒 Slots procesados: ${_slots.length}');
      
      if (_medicoAsignado == null || _slots.isEmpty) {
         throw Exception('Sin médico o sin fichas para esta fecha');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error en ScheduleScreen._fetchData: $e');
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      String errorTitle;
      String errorMsg;
      if (msg.contains('401') || msg.contains('unauthorized')) {
        errorTitle = 'Sesión expirada';
        errorMsg = 'Tu sesión ha expirado. Por favor, vuelve a iniciar sesión.';
      } else if (msg.contains('formato') || msg.contains('inválido') || msg.contains('sin médico') || msg.contains('sin fichas')) {
        // El backend devolvió data vacía o error de negocio
        errorTitle = 'Sin médico asignado';
        errorMsg = 'Por el momento no hay un médico asignado o fichas disponibles para '
            '${widget.tabShell.bookingState.specialty?.name ?? "esta especialidad"} '
            'en los horarios habilitados.\n\n'
            'Puedes intentar más tarde o seleccionar otra especialidad.';
      } else {
        errorTitle = 'No se pudo cargar la agenda';
        errorMsg = ErrorMapper.message(e, context: ErrorContext.cargarAgenda);
      }
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
        _errorTitle = errorTitle;
      });
    }
  }

  /// Refresca los slots silenciosamente sin mostrar loading ni perder selección.
  Future<void> _silentRefresh() async {
    if (!mounted || _isLoading || _medicoAsignado == null) return;
    try {
      final bs = widget.tabShell.bookingState;
      final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
      final idesp = int.tryParse(bs.specialty?.id ?? '') ?? 0;
      final fecha = _medicoAsignado!.fecha;

      final result = await _service.getMedicoAsignado(
        1, idsuc, idesp, fecha, 'ASE',
      );
      if (!mounted) return;

      final newSlots = result.toTimeSlots();

      setState(() {
        _medicoAsignado = result;
        _slots = newSlots;
      });
    } catch (_) {
      // Silencioso — no interrumpir al usuario
    }
  }

  /// Solo los slots disponibles (filtra los ocupados).
  List<TimeSlotModel> get _availableSlots =>
      _slots.where((s) => s.isAvailable && s.statusLevel != 'none').toList();

  /// Navega directamente al resumen al seleccionar una hora.
  void _onSlotSelected(TimeSlotModel slot) {
    if (_medicoAsignado != null) {
      widget.tabShell.bookingState.doctor = _medicoAsignado!.toDoctorModel();
      widget.tabShell.bookingState.idagenda = _medicoAsignado!.idagenda;
      widget.tabShell.bookingState.idcontrol = _medicoAsignado!.idcontrol;
      widget.tabShell.bookingState.idcon = _medicoAsignado!.idcon;
    }
    widget.tabShell.bookingState.selectedTime = slot.time;
    widget.tabShell.bookingState.idhora = slot.idhora;
    widget.tabShell.bookingState.slotNumber = slot.numero;
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => SummaryScreen(tabShell: widget.tabShell),
      ),
    );
  }

  /// Fecha para mostrar en la UI (la que se cargó con éxito).
  String get _fechaReserva {
    // Si _medicoAsignado tiene fecha, usar esa
    final serverDate = _medicoAsignado?.fecha;
    if (serverDate != null && serverDate.isNotEmpty) {
      try {
        final dt = DateFormat('yyyy-MM-dd').parse(serverDate);
        final formatter = DateFormat("EEEE, d 'de' MMMM", 'es');
        final formatted = formatter.format(dt);
        return formatted[0].toUpperCase() + formatted.substring(1);
      } catch (_) {}
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final formatter = DateFormat("EEEE, d 'de' MMMM", 'es');
    final formatted = formatter.format(tomorrow);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
      bs.specialty?.name ?? '',
    ];

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Horas Disponibles',
          style: context.texts.titleLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimaryC(isDark)),
        ),
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.92)
            : AppColors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder(isDark).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const BookingStepper(currentStep: 2),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isLoading
                    ? ListView(
                        key: const ValueKey('skeleton'),
                        padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                        children: [
                          BreadcrumbChips(labels: breadcrumbs),
                          SizedBox(height: context.r.spaceMd),
                          const SkeletonSchedule(),
                        ],
                      )
                    : _errorMessage != null
                        ? AppStateWidget.error(
                            key: const ValueKey('error'),
                            title: _errorTitle ?? 'No se pudo cargar la agenda',
                            message: _errorMessage!,
                            onRetry: _fetchData,
                            icon: (_errorTitle?.contains('médico') ?? false)
                                ? CupertinoIcons.person_badge_minus
                                : null,
                          )
                        : _buildContent(context, isDark, breadcrumbs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, List<String> breadcrumbs) {
    return ListView(
      key: const ValueKey('data'),
      padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
      children: [
        BreadcrumbChips(labels: breadcrumbs),
        SizedBox(height: context.r.spaceMd),
        FadeSlideIn(
          delay: const Duration(milliseconds: 50),
          offsetY: 10,
          child: _buildDateAndInfoHeader(context, isDark),
        ),
        const SizedBox(height: 18),
        if (_medicoAsignado != null)
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            offsetY: 15,
            child: _buildDoctorCard(context, isDark),
          ),
        SizedBox(height: context.r.spaceLg),
        FadeSlideIn(
          delay: const Duration(milliseconds: 150),
          offsetY: 10,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.accentForTheme(isDark),
                    borderRadius: BorderRadius.circular(context.r.spaceXs),
                  ),
                ),
                SizedBox(width: context.r.spaceSm),
                Text(
                  'Agenda médica',
                  style: context.texts.titleMedium.copyWith(
                    color: AppColors.accentForTheme(isDark),
                  ),
                ),
                if (_medicoAsignado != null) ...[
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: context.r.chipPaddingH, vertical: context.r.chipPaddingV),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(context.r.radiusSm),
                    ),
                    child: Text(
                      '${_availableSlots.length} fichas disponibles',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.successLight : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: context.r.spaceMd),
        if (_availableSlots.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.r.spaceXl, vertical: context.r.spaceXxl),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.warning.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      CupertinoIcons.clock,
                      size: 28,
                      color: AppColors.warning,
                    ),
                  ),
                  SizedBox(height: context.r.spaceMd),
                  Text(
                    'Sin fichas disponibles',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  SizedBox(height: context.r.spaceSm),
                  Text(
                    'Por el momento no hay fichas disponibles para '
                    '${widget.tabShell.bookingState.specialty?.name ?? "esta especialidad"}. '
                    'Intenta nuevamente más tarde o selecciona otra especialidad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondaryC(isDark),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildTimeGrid(context, isDark),
        SizedBox(height: context.r.spaceMd),
        // Hint de selección
        if (_availableSlots.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.r.spaceXxl),
            child: FadeSlideIn(
              delay: const Duration(milliseconds: 600),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.hand_draw, size: 16, color: AppColors.textSecondaryC(isDark)),
                  SizedBox(width: context.r.spaceSm),
                  Text(
                    'Toque una hora disponible para reservar',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: context.r.spaceXl),
      ],
    );
  }

  Widget _buildDateAndInfoHeader(BuildContext context, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      padding: EdgeInsets.all(context.r.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(context.r.cardRadius),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: isDark ? Border.all(color: AppColors.cardBorder(isDark)) : null,
      ),
      child: Column(
        children: [
          // Fecha destacada
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E5B85),
                  borderRadius: BorderRadius.circular(context.r.radiusMd),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: context.r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fechaReserva,
                      style: context.texts.headlineMedium.copyWith(
                        color: AppColors.accentForTheme(isDark),
                      ),
                    ),
                    SizedBox(height: context.r.spaceXs),
                    Text(
                      'Fecha disponible para reservas',
                      style: TextStyle(
                        color: AppColors.textSecondaryC(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.r.spaceMd),
          Container(height: 0.5, color: AppColors.dividerC(isDark)),
          SizedBox(height: context.r.spaceSm),
          // Info nota
          Row(
            children: [
              const Icon(
                Icons.info,
                size: 16,
                color: AppColors.info,
              ),
              SizedBox(width: context.r.spaceSm),
              Expanded(
                child: Text(
                  'Las reservas solo están habilitadas para el día de mañana.',
                  style: TextStyle(
                    color: AppColors.textSecondaryC(isDark),
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, bool isDark) {
    final doctor = _medicoAsignado!;
    final initial = doctor.medico.isNotEmpty ? doctor.medico[0] : '?';

    Widget doctorAvatar;
    if (doctor.foto.isNotEmpty) {
      try {
        final photoBytes = base64Decode(doctor.foto);
        doctorAvatar = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            photoBytes,
            width: context.r.listAvatarSize,
            height: context.r.listAvatarSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _doctorInitial(initial, isDark),
          ),
        );
      } catch (_) {
        doctorAvatar = _doctorInitial(initial, isDark);
      }
    } else {
      doctorAvatar = _doctorInitial(initial, isDark);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      padding: EdgeInsets.all(context.r.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(context.r.cardRadius),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: isDark ? Border.all(color: AppColors.cardBorder(isDark)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: context.r.listAvatarSize,
            height: context.r.listAvatarSize,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: doctorAvatar,
          ),
          SizedBox(width: context.r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.medico,
                  style: context.texts.headlineMedium.copyWith(
                    color: AppColors.accentForTheme(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.r.spaceXs),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 12, color: AppColors.textSecondaryC(isDark)),
                    SizedBox(width: context.r.spaceXs),
                    Expanded(
                      child: Text(
                        doctor.descripcionConsultorio,
                        style: TextStyle(
                          color: AppColors.textSecondaryC(isDark),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorInitial(String initial, bool isDark) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.accentForTheme(isDark),
          fontWeight: FontWeight.w700,
          fontSize: context.r.listAvatarSize * 0.42,
        ),
      ),
    );
  }

  Widget _buildTimeGrid(BuildContext context, bool isDark) {
    final available = _availableSlots;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(available.length, (i) {
          return FadeSlideIn(
            delay: Duration(milliseconds: 400 + (i * 50)),
            offsetY: 10,
            child: _timeChip(context, available[i], isDark),
          );
        }),
      ),
    );
  }

  Widget _timeChip(BuildContext context, TimeSlotModel slot, bool isDark) {
    // Solo slots disponibles llegan aquí
    final Color bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFF86EFAC);
    final Color textColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF14532D);
    final Color borderColor = isDark ? const Color(0xFF059669) : const Color(0xFF16A34A);

    return GestureDetector(
      onTap: () => _onSlotSelected(slot),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.r.spaceLg, vertical: context.r.spaceMd),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r.radiusMd),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.30),
              blurRadius: 10,
              spreadRadius: isDark ? 0 : 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.timeFormatted,
              style: context.texts.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
                fontSize: 18,
              ),
            ),
            SizedBox(height: context.r.spaceXs),
            Container(
              padding: EdgeInsets.symmetric(horizontal: context.r.spaceSm, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF059669).withValues(alpha: 0.3)
                    : const Color(0xFF065F46).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(context.r.badgeRadius),
              ),
              child: Text(
                'Disponible',
                style: context.texts.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
