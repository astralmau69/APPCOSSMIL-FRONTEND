import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/models/time_slot_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/image_enlarged_modal.dart';
import 'summary_screen.dart';

const _tag = 'ScheduleScreen';

class ScheduleScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const ScheduleScreen({super.key, required this.tabShell, this.onNext, this.onBack});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = ProgramacionService();

  List<TimeSlotModel> _slots = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _errorTitle;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _slotsSectionKey = GlobalKey();

  Timer? _refreshTimer;
  bool _isAppPaused = false;
  static const _refreshInterval = Duration(seconds: 15);
  static const _bookingTabIndex = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      // Pausar polling cuando: app en background, o el usuario navegó a otra tab.
      if (_isAppPaused) return;
      if (widget.tabShell.currentTabIndex != _bookingTabIndex) return;
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppPaused = state != AppLifecycleState.resumed;
    // Al volver de background, refrescar inmediatamente sin esperar al próximo tick.
    if (!_isAppPaused && mounted && !_isLoading) {
      _silentRefresh();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bs = widget.tabShell.bookingState;
      final idagenda = bs.idagenda ?? '';
      if (idagenda.isEmpty) throw Exception('Sin agenda seleccionada');

      final slots = await _service.getHorasAgenda(idagenda);

      if (!mounted) return;
      setState(() {
        _slots = slots;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_slotsSectionKey.currentContext != null) {
            Scrollable.ensureVisible(
              _slotsSectionKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              alignment: 0.1,
            );
          }
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorMapper.message(e, context: ErrorContext.cargarAgenda);
        _errorTitle = 'No se pudo cargar la agenda';
        _isLoading = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    if (!mounted || _isLoading) return;
    try {
      final bs = widget.tabShell.bookingState;
      final idagenda = bs.idagenda ?? '';
      if (idagenda.isEmpty) return;

      final newSlots = await _service.getHorasAgenda(idagenda);
      if (!mounted) return;
      setState(() { _slots = newSlots; });
    } catch (e) {
      // Silencioso esperado: refresh en background puede fallar por red sin afectar la UI.
      AppLogger.warn(_tag, 'Silent refresh falló (se intentará de nuevo en 15s)', e);
    }
  }

  /// Turnos disponibles, filtrando los pasados cuando la reserva es para hoy.
  ///
  /// Si el usuario eligió la fecha de HOY, solo muestra turnos cuya hora sea
  /// estrictamente posterior a la hora actual del dispositivo.
  List<TimeSlotModel> get _availableSlots {
    final base = _slots
        .where((s) => s.isAvailable)
        .toList();

    final selectedDate = widget.tabShell.bookingState.selectedDate ?? '';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (selectedDate != today) return base;

    // Es reserva para hoy — ocultar turnos cuya hora ya pasó.
    final now = DateTime.now();
    return base.where((slot) {
      try {
        final parts = slot.time.split(':');
        if (parts.length < 2) return true;
        final slotH = int.parse(parts[0]);
        final slotM = int.parse(parts[1]);
        // Incluir solo si el turno empieza DESPUÉS del minuto actual.
        return slotH > now.hour ||
            (slotH == now.hour && slotM > now.minute);
      } catch (e) {
        AppLogger.warn(_tag, 'No se pudo parsear hora de slot: ${slot.time}', e);
        return true; // incluir el turno si el formato es inesperado
      }
    }).toList();
  }

  Future<void> _onSlotSelected(TimeSlotModel slot) async {
    final bs = widget.tabShell.bookingState;
    final fecha = bs.selectedDate ?? '';
    if (fecha.isNotEmpty) {
      final hasConflict = await widget.tabShell.checkActiveCitaForDate(fecha);
      if (hasConflict) return;
    }

    if (!mounted) return;

    bs.selectedTime = slot.time;
    bs.idhora = slot.idhora;
    bs.slotNumber = slot.numero;
    if (widget.onNext != null) {
      widget.onNext!();
    } else {
      Navigator.push(
        context,
        AppPageRoute(
          builder: (_) => SummaryScreen(tabShell: widget.tabShell),
        ),
      );
    }
  }

  String get _fechaReserva {
    final selectedDate = widget.tabShell.bookingState.selectedDate;
    if (selectedDate != null && selectedDate.isNotEmpty) {
      try {
        final dt = DateFormat('yyyy-MM-dd').parse(selectedDate);
        final formatter = DateFormat("EEEE, d 'de' MMMM", 'es');
        final formatted = formatter.format(dt);
        return formatted[0].toUpperCase() + formatted.substring(1);
      } catch (e) {
        AppLogger.warn(_tag, 'No se pudo formatear fecha seleccionada: $selectedDate', e);
      }
    }

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final formatter = DateFormat("EEEE, d 'de' MMMM", 'es');
    final formatted = formatter.format(tomorrow);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Widget _buildBody(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
      bs.specialty?.name ?? '',
      bs.doctor?.fullName ?? '',
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? ListView(
              key: const ValueKey('skeleton'),
              padding: EdgeInsets.only(
                top: context.r.spaceMd,
                bottom: context.r.navBarBottomSpace,
              ),
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
                )
              : _buildContent(context, isDark, breadcrumbs),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onNext != null) {
      return _buildBody(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, List<String> breadcrumbs) {
    return ListView(
      key: const ValueKey('data'),
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: context.r.spaceMd,
        bottom: context.r.navBarBottomSpace,
      ),
      children: [
        BreadcrumbChips(labels: breadcrumbs),
        SizedBox(height: context.r.spaceMd),
        FadeSlideIn(
          delay: const Duration(milliseconds: 50),
          offsetY: 10,
          child: _buildDateAndInfoHeader(context, isDark),
        ),
        SizedBox(height: context.r.spaceMd),
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
            key: _slotsSectionKey,
            padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleccione su horario de atención',
                  style: context.texts.titleMedium.copyWith(
                    color: AppColors.accentForTheme(isDark),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Horas disponibles',
                  style: context.texts.titleMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: context.r.spaceSm),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.r.chipPaddingH, vertical: context.r.chipPaddingV),
                  decoration: BoxDecoration(
                    color: (_availableSlots.isEmpty ? AppColors.warning : AppColors.success)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(context.r.radiusSm),
                  ),
                  child: Text(
                    _availableSlots.isEmpty
                        ? 'Sin fichas disponibles'
                        : '${_availableSlots.length} fichas disponibles',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _availableSlots.isEmpty
                          ? AppColors.warning
                          : (isDark ? AppColors.successLight : AppColors.success),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: context.r.spaceMd),
        if (_availableSlots.isEmpty)
          Builder(builder: (_) {
            final empty = _buildEmptyState();
            return Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: context.r.spaceXl, vertical: context.r.spaceXxl),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: context.r.listAvatarSize * 1.4,
                      height: context.r.listAvatarSize * 1.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.warning.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        CupertinoIcons.clock,
                        size: context.r.iconLg,
                        color: AppColors.warning,
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    Text(
                      empty.title,
                      style: context.texts.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                    ),
                    SizedBox(height: context.r.spaceSm),
                    Text(
                      empty.message,
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: context.r.spaceLg),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(context.r.radiusMd),
                        onPressed: widget.onBack,
                        child: const Text(
                          'Cambiar de fecha',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
        else
          _buildTimeGrid(context, isDark),
        SizedBox(height: context.r.spaceMd),
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
                    'Seleccione un horario disponible',
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
                      'Fecha de Reserva',
                      style: context.texts.titleLarge.copyWith(
                        color: AppColors.textPrimaryC(isDark),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: context.r.spaceXs),
                    Text(
                      _fechaReserva,
                      style: context.texts.titleMedium.copyWith(
                        color: AppColors.accentForTheme(isDark),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(BuildContext context, bool isDark) {
    final doctor = widget.tabShell.bookingState.doctor;
    if (doctor == null) return const SizedBox.shrink();

    final initial = doctor.fullName.isNotEmpty ? doctor.fullName[0] : '?';

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
          GestureDetector(
            onTap: doctor.photoBytes != null
                ? () => _showDoctorPhotoEnlarged(doctor.photoBytes!, initial)
                : null,
            child: Container(
              width: context.r.listAvatarSize,
              height: context.r.listAvatarSize,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: _buildAvatarFromFoto(doctor.photoBytes, initial, isDark),
            ),
          ),
          SizedBox(width: context.r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Médico Seleccionado',
                  style: context.texts.headlineMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tabShell.bookingState.specialty?.name ?? '',
                  style: TextStyle(
                    color: AppColors.accentForTheme(isDark),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.r.spaceMd),
                Text(
                  doctor.fullName,
                  style: context.texts.bodyMedium.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.r.spaceSm),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: AppColors.textSecondaryC(isDark)),
                    SizedBox(width: context.r.spaceXs),
                    Expanded(
                      child: Text(
                        doctor.office,
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

  /// Muestra el modal de foto ampliada usando los photoBytes pre-procesados.
  void _showDoctorPhotoEnlarged(Uint8List bytes, String initial) {
    try {
      ImageEnlargedModal.showFromBytes(
        context: context,
        bytes: bytes,
        fallbackText: initial,
      );
    } catch (e) {
      AppLogger.warn(_tag, 'Error al abrir foto del médico ampliada', e);
    }
  }

  /// Renders avatar from the photoBytes.
  Widget _buildAvatarFromFoto(Uint8List? photoBytes, String initial, bool isDark) {
    if (photoBytes != null) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            photoBytes,
            width: context.r.listAvatarSize,
            height: context.r.listAvatarSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _doctorInitial(initial, isDark),
          ),
        );
      } catch (e) {
        AppLogger.warn(_tag, 'Error al renderizar foto del médico en agenda', e);
      }
    }
    return _doctorInitial(initial, isDark);
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

  /// Distingue por qué no hay slots: backend vacío, todas reservadas, o jornada
  /// terminada (cuando la reserva es para hoy y todas las horas ya pasaron).
  ({String title, String message}) _buildEmptyState() {
    final selectedDate = widget.tabShell.bookingState.selectedDate ?? '';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final specialty = widget.tabShell.bookingState.specialty?.name ?? 'esta especialidad';
    final hasRawSlots = _slots.isNotEmpty;
    final allOccupied = hasRawSlots && _slots.every((s) => !s.isAvailable);
    final isToday = selectedDate == today;

    if (!hasRawSlots) {
      return (
        title: 'Sin horarios cargados',
        message: 'El médico aún no tiene horarios habilitados para $specialty. '
            'Selecciona otro médico o vuelve más tarde.',
      );
    }
    if (allOccupied) {
      return (
        title: 'Fichas agotadas',
        message: 'Todas las fichas para $specialty ya fueron reservadas. '
            'Selecciona otro médico o elige otra fecha.',
      );
    }
    if (isToday) {
      return (
        title: 'Jornada terminada',
        message: 'No quedan turnos disponibles para hoy en $specialty: las horas restantes ya pasaron. '
            'Selecciona otra fecha o elige otro médico.',
      );
    }
    return (
      title: 'Sin fichas disponibles',
      message: 'Por el momento no hay fichas disponibles para $specialty. '
          'Selecciona otro médico o elige otra fecha.',
    );
  }

  Widget _buildTimeGrid(BuildContext context, bool isDark) {
    final available = _availableSlots;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: context.r.isTablet ? 180 : (context.r.isSmallPhone ? 110 : 140),
          crossAxisSpacing: context.r.gridSpacing,
          mainAxisSpacing: context.r.gridSpacing,
          childAspectRatio: 1.3,
        ),
        itemCount: available.length,
        itemBuilder: (context, i) {
          return FadeSlideIn(
            delay: Duration(milliseconds: 300 + (i * 15)),
            offsetY: 10,
            child: _timeChip(context, available[i], isDark),
          );
        },
      ),
    );
  }

  Widget _timeChip(BuildContext context, TimeSlotModel slot, bool isDark) {
    final Color bgColor = isDark ? const Color(0xFF064E3B) : const Color(0xFF86EFAC);
    final Color textColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF14532D);
    final Color borderColor = isDark ? const Color(0xFF059669) : const Color(0xFF16A34A);

    return GestureDetector(
      onTap: () => _onSlotSelected(slot),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(context.r.radiusMd),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.30),
              blurRadius: 8,
              spreadRadius: isDark ? 0 : 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.timeFormatted,
              style: context.texts.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: context.r.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
