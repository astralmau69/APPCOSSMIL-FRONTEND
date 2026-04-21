import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/models/doctor_agenda_model.dart';
import '../../../core/models/doctor_model.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../shell/tab_shell.dart';

class AgendaScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  const AgendaScreen({super.key, required this.tabShell, this.onNext, this.onBack});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  final _service = ProgramacionService();

  List<DoctorAgendaModel> _agendaDays = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAgenda();
  }

  Future<void> _loadAgenda() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bs = widget.tabShell.bookingState;
      final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
      final idmed = bs.doctor?.id ?? '';
      
      if (idmed.isEmpty) throw Exception('Doctor no seleccionado');

      final days = await _service.getAgendaMedicoMovil(
        idins: 1,
        idsuc: idsuc,
        idmed: idmed,
      );

      final today = DateTime.now();
      final List<DoctorAgendaModel> fullWeek = [];
      for (int i = 0; i < 7; i++) {
        final date = today.add(Duration(days: i));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        final existing = days.where((d) => d.fecha == dateStr).toList();
        if (existing.isNotEmpty) {
          fullWeek.add(existing.first);
        } else {
          final diaStr = DateFormat('EEEE', 'es').format(date).toUpperCase();
          fullWeek.add(DoctorAgendaModel(
            idagenda: '',
            idmed: idmed,
            idcon: 0,
            medico: bs.doctor?.fullName ?? '',
            dia: diaStr,
            fecha: dateStr,
            horaini: '',
            horafin: '',
            ase: 0,
            oferta: 0,
            demanda: 0,
            ope: 0,
            med: 0,
            adm: 0,
            foto: '',
            consultorio: '',
            mtrmin: '',
            disponibles: 0,
            iddia: date.weekday,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _agendaDays = fullWeek;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo cargar la agenda del médico.';
        _isLoading = false;
      });
    }
  }

  /// Cupos reales disponibles: usa `disponibles` si es != 0, sino calcula oferta-demanda.
  int _cuposLibres(DoctorAgendaModel day) {
    if (day.disponibles != 0) return day.disponibles;
    return day.oferta - day.demanda;
  }

  void _onDaySelected(DoctorAgendaModel day) {
    if (day.idagenda.isEmpty || _cuposLibres(day) <= 0) return;

    final bs = widget.tabShell.bookingState;
    bs.selectedDate = day.fecha;
    bs.idagenda = day.idagenda;
    bs.idcon = day.idcon;
    bs.idcontrol = '';

    if (bs.doctor != null) {
      bs.doctor = DoctorModel(
        id: bs.doctor!.id,
        fullName: bs.doctor!.fullName,
        office: bs.doctor!.office,
        fecha: day.fecha,
        dia: day.dia,
        foto: bs.doctor!.foto,
      );
    }

    if (widget.onNext != null) {
      widget.onNext!();
    }
  }

  String _formatFecha(String fecha) {
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(fecha);
      final f = DateFormat("d 'de' MMMM", 'es').format(dt);
      return f;
    } catch (_) {
      return fecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final bs = widget.tabShell.bookingState;

    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
      bs.specialty?.name ?? '',
      bs.doctor?.fullName ?? '',
    ];

    if (_isLoading) {
      return const AppStateWidget.loading();
    }

    if (_errorMessage != null) {
      return AppStateWidget.error(
        title: 'Error',
        message: _errorMessage!,
        onRetry: _loadAgenda,
      );
    }

    if (_agendaDays.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: AppStateWidget.empty(
              title: 'Sin agenda',
              message: 'El médico seleccionado no tiene agenda programada en este momento.',
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(r.paddingH, 0, r.paddingH, r.navBarBottomSpace + r.spaceMd),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(r.radiusMd),
                onPressed: widget.onBack,
                child: const Text(
                  'Volver a Médicos',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, 0),
            child: BreadcrumbChips(labels: breadcrumbs),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, r.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elige tu Fecha',
                  style: context.texts.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                SizedBox(height: r.spaceXs),
                Text(
                  'Agenda disponible de ${bs.doctor?.fullName ?? 'Médico'}',
                  style: context.texts.bodySmall.copyWith(
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(r.paddingH, 0, r.paddingH, r.navBarBottomSpace + 16),
          sliver: SliverList.builder(
            itemCount: _agendaDays.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: EdgeInsets.only(bottom: r.spaceMd),
                child: _buildDayCard(_agendaDays[i], isDark, r),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(DoctorAgendaModel day, bool isDark, AppResponsive r) {
    final cupos = _cuposLibres(day);
    final hasAgenda = day.idagenda.isNotEmpty;
    final isAvailable = hasAgenda && cupos > 0;
    final isOccupied = hasAgenda && cupos <= 0;
    
    final colorBg = isAvailable 
        ? AppColors.cardBg(isDark) 
        : isOccupied
            ? const Color(0xFFE53935).withValues(alpha: isDark ? 0.25 : 0.12) // Rojo más intenso
            : Colors.grey.withValues(alpha: isDark ? 0.2 : 0.08); // plomo
    
    final colorBorder = isAvailable
        ? AppColors.cardBorder(isDark)
        : isOccupied
            ? const Color(0xFFE53935).withValues(alpha: 0.5) // Borde rojo más intenso
            : Colors.grey.withValues(alpha: 0.3);

    final colorAccent = isAvailable 
        ? AppColors.primary 
        : isOccupied 
            ? const Color(0xFFD32F2F) // Rojo fuerte para texto
            : Colors.grey;

    return GestureDetector(
      onTap: () => hasAgenda && isAvailable ? _onDaySelected(day) : null,
      child: Container(
        decoration: BoxDecoration(
          color: colorBg,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(
            color: colorBorder,
            width: 1.0,
          ),
          boxShadow: isDark || (!isAvailable && !isOccupied) ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(r.cardPadding),
          child: Row(
            children: [
              Container(
                width: 60,
                padding: EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isAvailable 
                      ? AppColors.primary.withValues(alpha: 0.1) 
                      : colorAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.radiusSm),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day.dia.substring(0, 3).toUpperCase(),
                      style: context.texts.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isAvailable ? AppColors.primary : colorAccent,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      day.fecha.split('-').last,
                      style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isAvailable ? AppColors.textPrimaryC(isDark) : colorAccent,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFecha(day.fecha),
                      style: context.texts.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isAvailable ? AppColors.textPrimaryC(isDark) : AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    SizedBox(height: r.spaceXs),
                    Row(
                      children: [
                        Icon(CupertinoIcons.clock, size: 14, color: AppColors.textTertiaryC(isDark)),
                        SizedBox(width: 4),
                        Text(
                          hasAgenda ? day.rangoHorario : 'Sin horario',
                          style: context.texts.bodySmall.copyWith(
                            color: AppColors.textSecondaryC(isDark),
                          ),
                        ),
                        if (hasAgenda && day.consultorio.isNotEmpty) ...[
                          SizedBox(width: 12),
                          Icon(Icons.meeting_room_outlined, size: 14, color: AppColors.textTertiaryC(isDark)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              day.consultorio,
                              style: context.texts.bodySmall.copyWith(
                                color: AppColors.textSecondaryC(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable ? AppColors.success.withValues(alpha: 0.1) : colorAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAvailable ? '$cupos libres' : isOccupied ? 'Ocupado' : 'No atención',
                      style: context.texts.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? AppColors.success : colorAccent,
                      ),
                    ),
                  ),
                  if (isAvailable) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Tomar ficha',
                          style: context.texts.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(CupertinoIcons.chevron_right, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
