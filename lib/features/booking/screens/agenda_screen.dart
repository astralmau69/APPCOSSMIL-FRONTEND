import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/data/app_session_cache.dart';
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

      // 1. Obtener fecha del servidor (caché si está disponible) y agenda del backend.
      //    fechaServidor es estable durante la sesión: el orchestrator la pobla en
      //    AppSessionCache y aquí evitamos la llamada redundante.
      final cachedFecha = AppSessionCache.isLoaded ? AppSessionCache.fechaServidor : null;
      final fechaFuture = (cachedFecha != null && cachedFecha.isNotEmpty)
          ? Future.value(cachedFecha)
          : _service.getFechaServidor();

      final results = await Future.wait([
        fechaFuture,
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

      // 3. Agrupar los días del backend por fecha. Un mismo día puede tener
      //    varios turnos (ej. mañana 08:00–13:00 y tarde 17:00–21:00), por lo
      //    que se conservan TODOS los registros, no solo uno por fecha.
      final Map<String, List<DoctorAgendaModel>> byFecha = {};
      for (final d in backendDays) {
        byFecha.putIfAbsent(d.fecha, () => []).add(d);
      }
      // Ordenar los turnos de cada día por hora de inicio.
      for (final slots in byFecha.values) {
        slots.sort((a, b) => a.horaini.compareTo(b.horaini));
      }

      // 4. Construir la semana: HOY + 7 días más (8 en total)
      //    Garantiza que el mismo día de la semana siguiente siempre aparezca
      //    (ej. si hoy es miércoles → muestra hasta el siguiente miércoles).
      final List<_DiaAgenda> semana = [];
      for (int i = 0; i < 8; i++) {
        final fecha = hoySolo.add(Duration(days: i));
        final fechaStr = DateFormat('yyyy-MM-dd').format(fecha);
        final modelos = byFecha[fechaStr] ?? const <DoctorAgendaModel>[];

        semana.add(_DiaAgenda(
          fecha: fechaStr,
          fechaDate: fecha,
          modelos: modelos, // vacío → sin agenda en el backend
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

  void _onSlotSelected(_DiaAgenda dia, DoctorAgendaModel m) {
    if (!m.estado) return;

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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    final modelos = dia.modelos;
    final hasAgenda = modelos.isNotEmpty;
    final anyAvailable = modelos.any((m) => m.estado);

    // Color de acento del bloque-fecha según el "mejor" estado del día:
    // verde si algún turno está disponible, rojo si todos están agotados,
    // gris si no hay agenda en el backend.
    final Color colorAccent;
    if (anyAvailable) {
      colorAccent = AppColors.success;
    } else if (hasAgenda) {
      colorAccent = const Color(0xFFD32F2F);
    } else {
      colorAccent = Colors.grey;
    }

    final colorBg = colorAccent.withValues(alpha: isDark ? 0.14 : 0.08);
    final colorBorder = colorAccent.withValues(alpha: isDark ? 0.50 : 0.38);

    return AnimatedOpacity(
      opacity: hasAgenda ? 1.0 : 0.65,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: colorBg,
          borderRadius: BorderRadius.circular(r.cardRadius),
          border: Border.all(color: colorBorder, width: 1.0),
          boxShadow: (anyAvailable && !isDark)
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
            crossAxisAlignment: CrossAxisAlignment.start,
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

              // ── Info central: fecha + lista de turnos ────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFecha(dia.fechaDate),
                      style: context.texts.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: anyAvailable
                            ? AppColors.textPrimaryC(isDark)
                            : AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    SizedBox(height: r.spaceXs),
                    if (!hasAgenda)
                      _buildSinConsulta(isDark)
                    else
                      for (int i = 0; i < modelos.length; i++) ...[
                        if (i > 0) Divider(
                          height: r.spaceMd,
                          thickness: 0.5,
                          color: AppColors.textTertiaryC(isDark).withValues(alpha: 0.25),
                        ),
                        _buildSlotRow(dia, modelos[i], isDark, r),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fila "Sin consulta médica" (día sin agenda) ───────────────────────────
  Widget _buildSinConsulta(bool isDark) {
    return Row(
      children: [
        Icon(CupertinoIcons.clock, size: 14, color: AppColors.textTertiaryC(isDark)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Sin consulta médica',
            style: context.texts.bodySmall.copyWith(
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
        ),
      ],
    );
  }

  // ── Fila de un turno (horario + estado + acción) ──────────────────────────
  Widget _buildSlotRow(_DiaAgenda dia, DoctorAgendaModel m, bool isDark, AppResponsive r) {
    final isAvailable = m.estado;
    final accent = isAvailable ? AppColors.success : const Color(0xFFD32F2F);
    final estadoLabel = isAvailable ? 'Disponible' : 'Fichas agotadas';

    return GestureDetector(
      onTap: isAvailable ? () => _onSlotSelected(dia, m) : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 14, color: AppColors.textTertiaryC(isDark)),
                    const SizedBox(width: 4),
                    Text(
                      m.rangoHorario,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    if (m.consultorio.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.meeting_room_outlined,
                          size: 14, color: AppColors.textTertiaryC(isDark)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          m.consultorio,
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
          const SizedBox(width: 8),
          // ── Badge de estado + acción ─────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  estadoLabel,
                  style: context.texts.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isAvailable) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Tomar ficha',
                      style: context.texts.labelSmall.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(CupertinoIcons.chevron_right, size: 12, color: accent),
                  ],
                ),
              ],
            ],
          ),
        ],
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
  final List<DoctorAgendaModel> modelos; // vacío = sin agenda ese día
  final String idmed;
  final String medicoNombre;

  const _DiaAgenda({
    required this.fecha,
    required this.fechaDate,
    required this.modelos,
    required this.idmed,
    required this.medicoNombre,
  });
}
