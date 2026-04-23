import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/programacion_service.dart';
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

  /// Los 7 días siempre presentes — algunos pueden no tener agenda del backend.
  List<_DiaAgenda> _semana = [];
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

      // 1. Obtener fecha del servidor y datos del backend en paralelo
      final results = await Future.wait([
        _service.getFechaServidor(),
        _service.getAgendaMedicoMovil(idins: 1, idsuc: idsuc, idmed: idmed),
      ]);

      final fechaMap = results[0] as Map<String, String>;
      final backendDays = results[1] as List<DoctorAgendaModel>;

      // 2. Calcular la fecha base (hoy desde el servidor)
      final fechaServidorStr = fechaMap['fechaServidor'] ?? '';
      DateTime hoy;
      try {
        // El backend puede devolver ISO 8601 completo o solo "yyyy-MM-dd"
        hoy = DateTime.parse(fechaServidorStr.split('T').first);
      } catch (_) {
        hoy = DateTime.now();
      }
      final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);

      // 3. Indexar los días del backend por fecha para búsqueda O(1)
      final Map<String, DoctorAgendaModel> byFecha = {
        for (final d in backendDays) d.fecha: d,
      };

      // 4. Construir la semana: HOY + 7 días más (8 en total)
      //    Garantiza que el mismo día de la semana siguiente siempre aparezca
      //    (ej. si hoy es miércoles → muestra hasta el siguiente miércoles).
      final List<_DiaAgenda> semana = [];
      for (int i = 0; i < 8; i++) {
        final fecha = hoySolo.add(Duration(days: i));
        final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
        final modelo = byFecha[fechaStr];

        semana.add(_DiaAgenda(
          fecha: fechaStr,
          fechaDate: fecha,
          modelo: modelo, // null → sin agenda en el backend
          idmed: idmed,
          medicoNombre: bs.doctor?.fullName ?? '',
        ));
      }

      if (!mounted) return;
      setState(() {
        _semana = semana;
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

  void _onDaySelected(_DiaAgenda dia) {
    final m = dia.modelo;
    if (m == null || !m.estado) return;

    final bs = widget.tabShell.bookingState;
    bs.selectedDate = m.fecha;
    bs.idagenda = m.idagenda;
    bs.idcon = m.idcon;
    bs.idcontrol = '';

    if (bs.doctor != null) {
      bs.doctor = DoctorModel(
        id: bs.doctor!.id,
        fullName: bs.doctor!.fullName,
        office: m.consultorio,
        fecha: m.fecha,
        dia: m.dia,
        foto: bs.doctor!.foto,
      );
    }

    widget.onNext?.call();
  }

  String _formatFecha(DateTime fecha) {
    try {
      return DateFormat("d 'de' MMMM", 'es').format(fecha);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(fecha);
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

    if (_semana.isEmpty) {
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
            padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, r.spaceSm),
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
                SizedBox(height: r.spaceSm),
                // Leyenda
                _buildLegend(isDark, r),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, r.navBarBottomSpace + 16),
          sliver: SliverList.builder(
            itemCount: _semana.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: EdgeInsets.only(bottom: r.spaceMd),
                child: _buildDayCard(_semana[i], isDark, r),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Leyenda de estados ───────────────────────────────────────────────────

  Widget _buildLegend(bool isDark, AppResponsive r) {
    return Row(
      children: [
        _legendDot(AppColors.success, 'Disponible'),
        SizedBox(width: r.spaceMd),
        _legendDot(const Color(0xFFE53935), 'Fichas agotadas'),
        SizedBox(width: r.spaceMd),
        _legendDot(Colors.grey, 'Sin consulta'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Card de un día ───────────────────────────────────────────────────────

  Widget _buildDayCard(_DiaAgenda dia, bool isDark, AppResponsive r) {
    final modelo = dia.modelo;
    final hasAgenda = modelo != null && modelo.idagenda.isNotEmpty;
    final isAvailable = hasAgenda && modelo.estado;
    final isOccupied = hasAgenda && !modelo.estado;
    // Sin agenda del backend → "Sin consulta médica"
    final isSinConsulta = !hasAgenda;

    final Color colorBg;
    final Color colorBorder;
    final Color colorAccent;
    final String estadoLabel;

    if (isAvailable) {
      colorBg = AppColors.success.withValues(alpha: isDark ? 0.18 : 0.10);
      colorBorder = AppColors.success.withValues(alpha: isDark ? 0.55 : 0.45);
      colorAccent = AppColors.success;
      estadoLabel = 'Disponible';
    } else if (isOccupied) {
      colorBg = const Color(0xFFE53935).withValues(alpha: isDark ? 0.18 : 0.09);
      colorBorder = const Color(0xFFE53935).withValues(alpha: isDark ? 0.55 : 0.40);
      colorAccent = const Color(0xFFD32F2F);
      estadoLabel = 'Fichas agotadas';
    } else {
      // Sin consulta / sin datos del backend
      colorBg = Colors.grey.withValues(alpha: isDark ? 0.12 : 0.06);
      colorBorder = Colors.grey.withValues(alpha: isDark ? 0.30 : 0.22);
      colorAccent = Colors.grey;
      estadoLabel = 'Sin consulta médica';
    }

    final tappable = isAvailable;

    return GestureDetector(
      onTap: tappable ? () => _onDaySelected(dia) : null,
      child: AnimatedOpacity(
        opacity: isSinConsulta ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: colorBg,
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(color: colorBorder, width: 1.0),
            boxShadow: (isAvailable && !isDark)
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: EdgeInsets.all(r.cardPadding),
            child: Row(
              children: [
                // ── Bloque día / número ──────────────────────────────
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colorAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(r.radiusSm),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _diaNombre(dia.fechaDate).substring(0, 3).toUpperCase(),
                        style: context.texts.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dia.fechaDate.day.toString(),
                        style: context.texts.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorAccent,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: r.spaceMd),

                // ── Info central ─────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatFecha(dia.fechaDate),
                        style: context.texts.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isAvailable
                              ? AppColors.textPrimaryC(isDark)
                              : AppColors.textSecondaryC(isDark),
                        ),
                      ),
                      SizedBox(height: r.spaceXs),
                      Row(
                        children: [
                          Icon(CupertinoIcons.clock, size: 14, color: AppColors.textTertiaryC(isDark)),
                          const SizedBox(width: 4),
                          Text(
                            hasAgenda ? modelo.rangoHorario : 'Sin horario',
                            style: context.texts.bodySmall.copyWith(
                              color: AppColors.textSecondaryC(isDark),
                            ),
                          ),
                          if (hasAgenda && modelo.consultorio.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.meeting_room_outlined,
                                size: 14, color: AppColors.textTertiaryC(isDark)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                modelo.consultorio,
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

                // ── Badge de estado ──────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? AppColors.success
                            : isOccupied
                                ? const Color(0xFFD32F2F)
                                : colorAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        estadoLabel,
                        style: context.texts.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: (isAvailable || isOccupied) ? Colors.white : colorAccent,
                        ),
                      ),
                    ),
                    if (isAvailable) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Tomar ficha',
                            style: context.texts.labelSmall.copyWith(
                              color: colorAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(CupertinoIcons.chevron_right, size: 12, color: colorAccent),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nombre del día de la semana en español.
  String _diaNombre(DateTime fecha) {
    try {
      return DateFormat('EEEE', 'es').format(fecha);
    } catch (_) {
      const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      return dias[(fecha.weekday - 1) % 7];
    }
  }
}

// ── Data class para un día de la semana (con o sin agenda del backend) ────────

class _DiaAgenda {
  final String fecha;
  final DateTime fechaDate;
  final DoctorAgendaModel? modelo; // null = sin agenda ese día
  final String idmed;
  final String medicoNombre;

  const _DiaAgenda({
    required this.fecha,
    required this.fechaDate,
    required this.modelo,
    required this.idmed,
    required this.medicoNombre,
  });
}
