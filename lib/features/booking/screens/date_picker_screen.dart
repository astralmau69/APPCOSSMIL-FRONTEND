import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../shell/tab_shell.dart';

// ─── Modelo interno de disponibilidad por día ────────────────────────────────

enum _DayStatus { loading, available, unavailable }

class _DaySlot {
  final DateTime date;
  _DayStatus status;
  int doctorCount;

  _DaySlot({required this.date})
      : status = _DayStatus.loading,
        doctorCount = 0;
}

// ─── Widget principal ─────────────────────────────────────────────────────────

/// Paso 2 del flujo de reserva: selección de fecha.
///
/// Muestra un carrusel horizontal de 7 días comenzando desde HOY, excluyendo
/// domingos. Cada día consulta la disponibilidad de médicos en paralelo;
/// días sin médicos se pintan en rojo.
class DatePickerScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onNext;

  const DatePickerScreen({super.key, required this.tabShell, this.onNext});

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  final _service = ProgramacionService();

  List<_DaySlot> _days = [];
  String? _selectedDateStr;
  bool _isInitializing = true;
  bool _isCheckingConflict = false;

  // Meses abreviados en español
  static const _months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  // Días abreviados en español (weekday 1=lunes … 7=domingo)
  static const _weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ─── Inicialización ──────────────────────────────────────────────────────

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _selectedDateStr = null;
    });

    // Siempre iniciar desde hoy — la ventana de reserva va desde hoy
    // hasta completar 7 días hábiles excluyendo domingos.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = _buildDays(today);

    if (!mounted) return;
    setState(() => _isInitializing = false);

    // Disparar todas las consultas de disponibilidad en paralelo (fire-and-forget)
    _loadAllAvailability();
  }

  /// Genera [count] días a partir de [start], saltando domingos.
  /// Ejemplo: lunes → lun, mar, mié, jue, vie, sáb, lun(sig) = 7 días.
  List<_DaySlot> _buildDays(DateTime start, {int count = 7}) {
    final result = <_DaySlot>[];
    var current = start;
    while (result.length < count) {
      if (current.weekday != DateTime.sunday) {
        result.add(_DaySlot(date: current));
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  // ─── Carga de disponibilidad (todas en paralelo) ──────────────────────────

  void _loadAllAvailability() {
    final bs = widget.tabShell.bookingState;
    final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
    final idesp = int.tryParse(bs.specialty?.id ?? '') ?? 0;

    for (int i = 0; i < _days.length; i++) {
      final index = i;
      final fechaStr = DateFormat('yyyy-MM-dd').format(_days[i].date);

      _service
          .getMedicosAgenda(idins: 1, idsuc: idsuc, fecha: fechaStr, idesp: idesp)
          .then((doctors) {
        if (!mounted) return;
        setState(() {
          _days[index].status =
              doctors.isNotEmpty ? _DayStatus.available : _DayStatus.unavailable;
          _days[index].doctorCount = doctors.length;
        });
      }).catchError((e) {
        AppLogger.warn('DatePickerScreen', 'Error al cargar disponibilidad para $fechaStr: $e');
        if (!mounted) return;
        setState(() {
          _days[index].status = _DayStatus.unavailable;
        });
      });
    }
  }

  // ─── Interacción ─────────────────────────────────────────────────────────

  void _onDayTapped(_DaySlot slot) {
    if (slot.status != _DayStatus.available) return;
    final str = DateFormat('yyyy-MM-dd').format(slot.date);
    setState(() => _selectedDateStr = str);
  }

  Future<void> _onContinue() async {
    if (_selectedDateStr == null || _isCheckingConflict) return;

    setState(() => _isCheckingConflict = true);

    // Verificar si el beneficiario ya tiene cita para la fecha seleccionada.
    // checkActiveCitaForDate muestra el modal de conflicto internamente si aplica.
    final hasConflict =
        await widget.tabShell.checkActiveCitaForDate(_selectedDateStr!);

    if (!mounted) return;
    setState(() => _isCheckingConflict = false);

    if (hasConflict) return; // Modal ya fue mostrado; no avanzar.

    widget.tabShell.bookingState.selectedDate = _selectedDateStr;
    widget.onNext?.call();
  }

  // ─── Helpers de formato ───────────────────────────────────────────────────

  String _dayAbbrev(DateTime date) => _weekDays[date.weekday - 1];

  String _monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

  String _formatSelectedDate(String dateStr) {
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(dateStr);
      final f = DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es').format(dt);
      return f[0].toUpperCase() + f.substring(1);
    } catch (_) {
      return dateStr;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final bs = widget.tabShell.bookingState;

    if (_isInitializing) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
      bs.specialty?.name ?? '',
    ];

    return Column(
      children: [
        // ── Contenido scrollable ──────────────────────────────────────────
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // Breadcrumbs
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      r.paddingH, r.spaceSm, r.paddingH, 0),
                  child: BreadcrumbChips(labels: breadcrumbs),
                ),
              ),

              // Título
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      r.paddingH, r.spaceMd, r.paddingH, r.spaceSm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona una fecha',
                        style: context.texts.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryC(isDark),
                        ),
                      ),
                      SizedBox(height: r.spaceXs),
                      Text(
                        bs.specialty?.name != null
                            ? 'Disponibilidad para ${bs.specialty!.name}'
                            : 'Disponibilidad de los próximos días',
                        style: context.texts.bodySmall.copyWith(
                          color: AppColors.textSecondaryC(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Carrusel de días
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _dayCardHeight(r),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                    itemCount: _days.length,
                    itemBuilder: (ctx, i) =>
                        _buildDayCard(_days[i], isDark, r),
                  ),
                ),
              ),

              // Leyenda
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      r.paddingH, r.spaceMd, r.paddingH, 0),
                  child: Row(
                    children: [
                      _buildLegend(AppColors.primary,
                          isDark ? Colors.white70 : Colors.black54,
                          'Disponible'),
                      SizedBox(width: r.spaceLg),
                      _buildLegend(AppColors.error,
                          isDark ? Colors.white70 : Colors.black54,
                          'Sin médicos'),
                    ],
                  ),
                ),
              ),

              // Banner de fecha seleccionada
              if (_selectedDateStr != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        r.paddingH, r.spaceMd, r.paddingH, 0),
                    child: AnimatedContainer(
                      duration: AppDurations.normal,
                      padding: EdgeInsets.all(r.spaceMd),
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius:
                            BorderRadius.circular(r.cardRadius),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.calendar_badge_plus,
                            color: AppColors.primary,
                            size: r.iconMd,
                          ),
                          SizedBox(width: r.spaceSm),
                          Expanded(
                            child: Text(
                              _formatSelectedDate(_selectedDateStr!),
                              style: context.texts.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Espacio final
              SliverToBoxAdapter(child: SizedBox(height: r.spaceLg)),
            ],
          ),
        ),

        // ── Botón continuar ───────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
              r.paddingH, r.spaceSm, r.paddingH,
              r.navBarBottomSpace + r.spaceMd),
          child: SizedBox(
            width: double.infinity,
            height: r.buttonHeight,
            child: CupertinoButton(
              color: (_selectedDateStr != null && !_isCheckingConflict)
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(r.buttonRadius),
              onPressed: (_selectedDateStr != null && !_isCheckingConflict)
                  ? _onContinue
                  : null,
              child: _isCheckingConflict
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Text(
                      'Continuar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: r.isTablet ? 18.0 : 16.0,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Tarjeta de día ───────────────────────────────────────────────────────

  double _dayCardHeight(AppResponsive r) =>
      r.isSmallPhone ? 100.0 : (r.isTablet ? 130.0 : 114.0);

  double _dayCardWidth(AppResponsive r) =>
      r.isSmallPhone ? 66.0 : (r.isTablet ? 90.0 : 76.0);

  Widget _buildDayCard(_DaySlot slot, bool isDark, AppResponsive r) {
    final dateStr = DateFormat('yyyy-MM-dd').format(slot.date);
    final isSelected = _selectedDateStr == dateStr;
    final isLoading = slot.status == _DayStatus.loading;
    final isUnavailable = slot.status == _DayStatus.unavailable;
    final isAvailable = slot.status == _DayStatus.available;

    // ── Colores según estado ──────────────────────────────────────────────
    final Color bgColor;
    final Color borderColor;
    final Color dayNameColor;
    final Color dayNumColor;
    final Color monthColor;

    if (isSelected) {
      bgColor      = AppColors.primary;
      borderColor  = AppColors.primary;
      dayNameColor = Colors.white.withValues(alpha: 0.85);
      dayNumColor  = Colors.white;
      monthColor   = Colors.white.withValues(alpha: 0.75);
    } else if (isUnavailable) {
      bgColor      = AppColors.error.withValues(alpha: isDark ? 0.13 : 0.07);
      borderColor  = AppColors.error.withValues(alpha: 0.45);
      dayNameColor = AppColors.error.withValues(alpha: 0.8);
      dayNumColor  = AppColors.error;
      monthColor   = AppColors.error.withValues(alpha: 0.65);
    } else if (isAvailable) {
      bgColor      = isDark ? AppColors.darkElevated : Colors.white;
      borderColor  = AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.3);
      dayNameColor = AppColors.textSecondaryC(isDark);
      dayNumColor  = AppColors.textPrimaryC(isDark);
      monthColor   = AppColors.textTertiaryC(isDark);
    } else {
      // loading
      bgColor      = isDark ? AppColors.darkElevated : AppColors.surfaceVariant;
      borderColor  = AppColors.cardBorder(isDark);
      dayNameColor = AppColors.textTertiaryC(isDark);
      dayNumColor  = AppColors.textSecondaryC(isDark);
      monthColor   = AppColors.textTertiaryC(isDark);
    }

    final cardW = _dayCardWidth(r);
    final bigFontSize = r.isSmallPhone ? 24.0 : (r.isTablet ? 34.0 : 28.0);

    return GestureDetector(
      onTap: isAvailable ? () => _onDayTapped(slot) : null,
      child: AnimatedContainer(
        duration: AppDurations.normal,
        curve: Curves.easeOut,
        width: cardW,
        margin: EdgeInsets.only(right: r.spaceSm),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  )
                ]
              : AppColors.cardShadowFor(isDark),
        ),
        child: isLoading
            ? _buildLoadingSkeleton(isDark, r)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Nombre del día (Lun, Mar…)
                  Text(
                    _dayAbbrev(slot.date),
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 10.0 : 12.0,
                      fontWeight: FontWeight.w600,
                      color: dayNameColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: r.spaceXs * 0.5),

                  // Número del día (grande)
                  Text(
                    '${slot.date.day}',
                    style: TextStyle(
                      fontSize: bigFontSize,
                      fontWeight: FontWeight.w900,
                      color: dayNumColor,
                      height: 1.05,
                    ),
                  ),
                  SizedBox(height: r.spaceXs * 0.5),

                  // Mes + año
                  Text(
                    _monthYear(slot.date),
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 8.0 : 9.5,
                      fontWeight: FontWeight.w500,
                      color: monthColor,
                      letterSpacing: 0.1,
                    ),
                  ),

                  SizedBox(height: r.spaceXs),

                  // Indicador de estado (dot verde / X roja)
                  if (isAvailable && !isSelected)
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    )
                  else if (isUnavailable)
                    Icon(CupertinoIcons.xmark_circle_fill,
                        size: 12, color: AppColors.error)
                  else if (isSelected)
                    Icon(CupertinoIcons.checkmark_circle_fill,
                        size: 12, color: Colors.white),
                ],
              ),
      ),
    );
  }

  // ─── Skeleton de carga por tarjeta ────────────────────────────────────────

  Widget _buildLoadingSkeleton(bool isDark, AppResponsive r) {
    final base = AppColors.cardBorder(isDark);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _shimmerBox(28, 10, base, r),
        SizedBox(height: r.spaceXs),
        _shimmerBox(38, 28, base, r),
        SizedBox(height: r.spaceXs),
        _shimmerBox(44, 10, base, r),
      ],
    );
  }

  Widget _shimmerBox(double w, double h, Color color, AppResponsive r) =>
      Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(r.radiusSm),
        ),
      );

  // ─── Leyenda ──────────────────────────────────────────────────────────────

  Widget _buildLegend(Color dotColor, Color textColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
