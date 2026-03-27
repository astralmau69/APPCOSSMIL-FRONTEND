import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/time_slot_model.dart';
import '../../../core/models/medico_asignado_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
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
  String? _selectedTime;
  String? _selectedIdhora;
  int? _selectedSlotNumber;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Fecha para el API. Pruebas: Mañana priorizado, Hoy como fallback.
  String _getFecha(int daysOffset) {
    final date = DateTime.now().add(Duration(days: daysOffset));
    return DateFormat('yyyy-MM-dd').format(date);
  }

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
      final idhorario = bs.idhorario ?? 0;

      // Priorizamos HOY como pidió el usuario ("que muestre nomas de hoy luego se cambiara")
      final fechaHoy = _getFecha(0);
      debugPrint('🌐 Consultando medico-asignado (HOY): idins=1, idsuc=$idsuc, idesp=$idesp, fecha=$fechaHoy, idhorario=$idhorario');
      
      try {
        _medicoAsignado = await _service.getMedicoAsignado(
          1, idsuc, idesp, fechaHoy, idhorario,
        );
        _slots = _medicoAsignado!.toTimeSlots();
      } catch (e) {
        debugPrint('⚠️ Falló consulta para hoy: $e. Intentando con MAÑANA como fallback...');
        _medicoAsignado = null;
        _slots = [];
      }

      // Si hoy no devolvió slots, probamos MAÑANA
      if (_slots.isEmpty) {
        final fechaManana = _getFecha(1);
        debugPrint('🌐 Consultando medico-asignado (MAÑANA): idins=1, idsuc=$idsuc, idesp=$idesp, fecha=$fechaManana, idhorario=$idhorario');
        _medicoAsignado = await _service.getMedicoAsignado(
          1, idsuc, idesp, fechaManana, idhorario,
        );
        _slots = _medicoAsignado!.toTimeSlots();
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
        errorMsg = 'Ocurrió un problema al consultar la agenda médica. '
            'Verifica tu conexión a internet e intenta nuevamente.';
      }
      setState(() {
        _errorMessage = errorMsg;
        _isLoading = false;
        _errorTitle = errorTitle;
      });
    }
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
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimaryC(isDark)),
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? const AppStateWidget.loading()
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
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, List<String> breadcrumbs) {
    return ListView(
      key: const ValueKey('data'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        BreadcrumbChips(labels: breadcrumbs),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        FadeSlideIn(
          delay: const Duration(milliseconds: 150),
          offsetY: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.accentForTheme(isDark),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Agenda médica',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.accentForTheme(isDark),
                  ),
                ),
                if (_medicoAsignado != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_medicoAsignado!.fichasDisponibles} fichas disponibles',
                      style: TextStyle(
                        fontSize: 12,
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
        const SizedBox(height: 14),
        if (_slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
                  const SizedBox(height: 16),
                  Text(
                    'Sin fichas disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Por el momento no hay fichas disponibles para '
                    '${widget.tabShell.bookingState.specialty?.name ?? "esta especialidad"}. '
                    'Intenta nuevamente más tarde o selecciona otra especialidad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
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
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 600),
            child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              onPressed: _selectedTime == null
                  ? null
                  : () {
                      if (_medicoAsignado != null) {
                        widget.tabShell.bookingState.doctor =
                            _medicoAsignado!.toDoctorModel();
                        widget.tabShell.bookingState.idagenda =
                            _medicoAsignado!.idagenda;
                        widget.tabShell.bookingState.idcontrol =
                            _medicoAsignado!.idcontrol;
                      }
                      widget.tabShell.bookingState.selectedTime =
                          _selectedTime;
                      widget.tabShell.bookingState.idhora =
                          _selectedIdhora;
                      widget.tabShell.bookingState.slotNumber =
                          _selectedSlotNumber;
                      Navigator.push(
                        context,
                        AppPageRoute(
                          builder: (_) => SummaryScreen(
                              tabShell: widget.tabShell),
                        ),
                      );
                    },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.arrow_right,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDateAndInfoHeader(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E5B85), Color(0xFF082F49)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fechaReserva,
                      style: AppTypography.headlineSmall.copyWith(
                        fontSize: 17,
                        color: AppColors.accentForTheme(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Fecha disponible para reservas',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryC(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 0.5, color: AppColors.dividerC(isDark)),
          const SizedBox(height: 10),
          // Info nota
          Row(
            children: [
              const Icon(
                Icons.info,
                size: 16,
                color: AppColors.info,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Las reservas solo están habilitadas para el día de mañana.',
                  style: TextStyle(
                    fontSize: 13,
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: isDark ? Border.all(color: AppColors.cardBorder(isDark)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.accentForTheme(isDark),
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.medico,
                  style: AppTypography.headlineSmall.copyWith(
                    fontSize: 17,
                    color: AppColors.accentForTheme(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 12, color: AppColors.textSecondaryC(isDark)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doctor.descripcionConsultorio,
                        style: TextStyle(
                          fontSize: 14,
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

  Widget _buildTimeGrid(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(_slots.length, (i) {
          return FadeSlideIn(
            delay: Duration(milliseconds: 400 + (i * 50)),
            offsetY: 10,
            child: _timeChip(context, _slots[i], isDark),
          );
        }),
      ),
    );
  }

  Widget _timeChip(BuildContext context, TimeSlotModel slot, bool isDark) {
    final isSelected = _selectedTime == slot.time;
    final isDisabled = !slot.isAvailable || slot.statusLevel == 'none';

    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isDisabled) {
      // Ocupadas en rojo claro y visible
      bgColor = isDark ? AppColors.slotUnavailableBgDark : AppColors.slotUnavailableBg;
      textColor = isDark ? AppColors.slotUnavailableTextDark : AppColors.slotUnavailableText;
      borderColor = isDark ? AppColors.slotUnavailableBorderDark : AppColors.slotUnavailableBorder;
    } else if (isSelected) {
      // Seleccionada en verde sólido
      bgColor = AppColors.success;
      textColor = AppColors.white;
      borderColor = AppColors.success;
    } else {
      // Disponible (no seleccionada) en verde claro
      bgColor = isDark ? AppColors.success.withValues(alpha: 0.15) : AppColors.successLight;
      textColor = isDark ? AppColors.successLight : AppColors.success;
      borderColor = isDark ? AppColors.success.withValues(alpha: 0.3) : const Color(0xFFBBF7D0);
    }

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                _selectedTime = isSelected ? null : slot.time;
                _selectedIdhora = isSelected ? null : slot.idhora;
                _selectedSlotNumber = isSelected ? null : slot.numero;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            slot.time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
              decoration: isDisabled ? TextDecoration.lineThrough : null,
              decorationColor: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
