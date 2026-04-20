import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/theme/app_constants.dart';
import '../models/medico_model.dart';
import '../services/calendario_service.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  final _service = CalendarioService();
  final _searchCtrl = TextEditingController();

  // Estado principal
  List<MedicoBusquedaModel> _resultadosBusqueda = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  // true = vista por defecto (todos los médicos), false = resultado de búsqueda
  bool _esVistaPorDefecto = true;

  // Strip semanal
  DateTime _fecha = DateTime.now();
  late final List<DateTime> _semana;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    // Lunes de la semana actual
    final lunes = hoy.subtract(Duration(days: hoy.weekday - 1));
    // Solo días laborales (Lun-Vie) de la semana actual — los médicos
    // no tienen horario los sábados ni domingos según el campo `dia` de la API.
    _semana = List.generate(14, (i) => DateTime(lunes.year, lunes.month, lunes.day + i))
        .where((d) => d.weekday >= DateTime.monday && d.weekday <= DateTime.friday)
        .take(10) // dos semanas laborales como máximo
        .toList();
    // Seleccionar hoy si es laborable; si no (fin de semana), el próximo lunes
    _fecha = _semana.firstWhere(
      (d) => d.year == hoy.year && d.month == hoy.month && d.day == hoy.day,
      orElse: () => _semana.firstWhere(
        (d) => !d.isBefore(hoy),
        orElse: () => _semana.first,
      ),
    );
    _cargarAgenda();
  }

  @override
  void dispose() {
    _service.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────────────────────

  Future<void> _cargarAgenda() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _esVistaPorDefecto = true;
    });
    try {
      // buscarMedicos sin filtros devuelve TODOS los médicos del centro,
      // independientemente de la especialidad. Esto evita el problema de
      // mostrar "sin médicos" cuando el id de especialidad no coincide.
      final result = await _service.buscarMedicos();
      if (!mounted) return;
      setState(() {
        _resultadosBusqueda = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los médicos. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _buscarMedico(String query) async {
    if (query.trim().isEmpty) {
      _searchCtrl.clear();
      _cargarAgenda();
      return;
    }
    setState(() {
      _isSearching = true;
      _esVistaPorDefecto = false;
      _error = null;
    });
    try {
      final result = await _service.buscarMedicos(pat: query.trim().toUpperCase());
      if (!mounted) return;
      setState(() {
        _resultadosBusqueda = result;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error en la búsqueda.';
        _isSearching = false;
      });
    }
  }

  // ── Horario modal / dialog ─────────────────────────────────────────────────

  Future<void> _mostrarHorario(BuildContext ctx, String idmed, String nombre) async {
    final isTablet = ctx.isTablet;

    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    if (isTablet) {
      showDialog(
        context: ctx,
        builder: (_) => _HorarioDialog(
          nombre: nombre,
          idmed: idmed,
          service: _service,
          isDark: isDark,
        ),
      );
    } else {
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _HorarioSheet(
          nombre: nombre,
          idmed: idmed,
          service: _service,
          isDark: isDark,
        ),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? Colors.transparent : const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(child: _buildBody(isDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.paddingH, AppSpacing.md, r.paddingH, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Text(
            'Calendario de Atención',
            style: context.texts.headlineMedium.copyWith(
              color: AppColors.textPrimaryC(isDark),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat("EEEE d 'de' MMMM yyyy", 'es_BO').format(_fecha),
            style: context.texts.bodySmall.copyWith(
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Buscador premium
          _SearchBar(
            controller: _searchCtrl,
            isDark: isDark,
            onSubmitted: _buscarMedico,
            onClear: () {
              _searchCtrl.clear();
              _cargarAgenda();
            },
          ),

          const SizedBox(height: AppSpacing.sm),

          // Strip semanal de 7 días
          _WeekStrip(
            semana: _semana,
            seleccionada: _fecha,
            isDark: isDark,
            onDayTap: (dia) {
              if (_isSameDay(dia, _fecha) && _esVistaPorDefecto) return;
              _searchCtrl.clear();
              setState(() => _fecha = dia);
              _cargarAgenda();
            },
          ),

          if (!_esVistaPorDefecto) ...[
            const SizedBox(height: AppSpacing.sm),
            _PillChip(
              label: 'Ver todos',
              active: false,
              isDark: isDark,
              onTap: () {
                _searchCtrl.clear();
                _cargarAgenda();
              },
            ),
          ],

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading || _isSearching) return _LoadingView(isDark: isDark);
    if (_error != null) return _ErrorView(message: _error!, onRetry: _cargarAgenda, isDark: isDark);
    if (_resultadosBusqueda.isEmpty) return _EmptyView(isDark: isDark, esBusqueda: !_esVistaPorDefecto);
    return _BusquedaList(
      resultados: _resultadosBusqueda,
      isDark: isDark,
      onTap: (m) => _mostrarHorario(context, m.idmed, m.nombreCompleto),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buscador premium
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF191C1E).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: AppColors.textPrimaryC(isDark),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por apellido del médico…',
          hintStyle: TextStyle(
            color: AppColors.textTertiaryC(isDark),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textTertiaryC(isDark),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textTertiaryC(isDark), size: 18),
                    onPressed: onClear,
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Strip semanal (7 días desde hoy)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final List<DateTime> semana;
  final DateTime seleccionada;
  final bool isDark;
  final ValueChanged<DateTime> onDayTap;

  const _WeekStrip({
    required this.semana,
    required this.seleccionada,
    required this.isDark,
    required this.onDayTap,
  });

  bool _isSelected(DateTime d) =>
      d.year == seleccionada.year &&
      d.month == seleccionada.month &&
      d.day == seleccionada.day;

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: semana.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final dia = semana[i];
          final selected = _isSelected(dia);
          final today = _isToday(dia);
          final past = dia.isBefore(DateTime.now().subtract(const Duration(days: 1)));

          return GestureDetector(
            onTap: past ? null : () => onDayTap(dia),
            child: Opacity(
              opacity: past ? 0.38 : 1.0,
              child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0056D2), Color(0xFF007AFF)],
                      )
                    : null,
                color: selected
                    ? null
                    : (isDark ? AppColors.darkElevated : Colors.white),
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected ? [] : AppColors.softShadow,
                border: today && !selected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE', 'es_BO')
                        .format(dia)
                        .toUpperCase()
                        .substring(0, 3),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textTertiaryC(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dia.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : (today
                              ? AppColors.primary
                              : AppColors.textPrimaryC(isDark)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Dot indicador "hoy"
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.6)
                          : (today ? AppColors.primary : Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _PillChip({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : (isDark ? AppColors.darkElevated : const Color(0xFFEEF1F5)),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active
                ? Colors.white
                : AppColors.textSecondaryC(isDark),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de médicos
// ─────────────────────────────────────────────────────────────────────────────

class _BusquedaList extends StatelessWidget {
  final List<MedicoBusquedaModel> resultados;
  final bool isDark;
  final ValueChanged<MedicoBusquedaModel> onTap;

  const _BusquedaList({
    required this.resultados,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ListView.separated(
      padding:
          EdgeInsets.fromLTRB(r.paddingH, 0, r.paddingH, AppSpacing.xxl),
      itemCount: resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final m = resultados[i];
        return GestureDetector(
          onTap: () => onTap(m),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadowFor(isDark),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Row(
              children: [
                _Avatar(
                  bytes: null,
                  initials: m.initials,
                  isDark: isDark,
                  radius: 24,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    m.nombreCompleto,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textTertiaryC(isDark), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar con foto o iniciales
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final Uint8List? bytes;
  final String initials;
  final bool isDark;
  final double radius;

  const _Avatar({
    required this.bytes,
    required this.initials,
    required this.isDark,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primaryLight,
          width: 2,
        ),
        color: isDark ? AppColors.darkElevated : AppColors.primaryLight,
      ),
      child: ClipOval(
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: radius * 0.55,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BottomSheet de horario (móvil)
// ─────────────────────────────────────────────────────────────────────────────

class _HorarioSheet extends StatefulWidget {
  final String nombre;
  final String idmed;
  final CalendarioService service;
  final bool isDark;

  const _HorarioSheet({
    required this.nombre,
    required this.idmed,
    required this.service,
    required this.isDark,
  });

  @override
  State<_HorarioSheet> createState() => _HorarioSheetState();
}

class _HorarioSheetState extends State<_HorarioSheet> {
  List<MedicoHorarioModel> _horarios = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await widget.service.getHorarioMedico(idmed: widget.idmed);
      if (!mounted) return;
      setState(() {
        _horarios = h;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el horario.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevatedBg(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Pill indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFFDDE1E6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Horario semanal',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryC(isDark),
                  ),
                ),
                const SizedBox(height: 20),
                _HorarioBody(
                    loading: _loading, error: _error, horarios: _horarios, isDark: isDark),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de horario (tablet)
// ─────────────────────────────────────────────────────────────────────────────

class _HorarioDialog extends StatefulWidget {
  final String nombre;
  final String idmed;
  final CalendarioService service;
  final bool isDark;

  const _HorarioDialog({
    required this.nombre,
    required this.idmed,
    required this.service,
    required this.isDark,
  });

  @override
  State<_HorarioDialog> createState() => _HorarioDialogState();
}

class _HorarioDialogState extends State<_HorarioDialog> {
  List<MedicoHorarioModel> _horarios = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await widget.service.getHorarioMedico(idmed: widget.idmed);
      if (!mounted) return;
      setState(() {
        _horarios = h;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el horario.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.elevatedBg(isDark),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nombre,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryC(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Horario semanal',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryC(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textTertiaryC(isDark)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _HorarioBody(
                  loading: _loading,
                  error: _error,
                  horarios: _horarios,
                  isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cuerpo de horario compartido (chips de días + turnos)
// ─────────────────────────────────────────────────────────────────────────────

class _HorarioBody extends StatefulWidget {
  final bool loading;
  final String? error;
  final List<MedicoHorarioModel> horarios;
  final bool isDark;

  const _HorarioBody({
    required this.loading,
    required this.error,
    required this.horarios,
    required this.isDark,
  });

  @override
  State<_HorarioBody> createState() => _HorarioBodyState();
}

class _HorarioBodyState extends State<_HorarioBody> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (widget.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          widget.error!,
          style: const TextStyle(color: AppColors.error, fontSize: 13),
        ),
      );
    }

    if (widget.horarios.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Sin horario registrado.',
          style: TextStyle(
              color: AppColors.textSecondaryC(widget.isDark), fontSize: 14),
        ),
      );
    }

    final horarios = widget.horarios;
    final selected =
        _selectedIndex < horarios.length ? horarios[_selectedIndex] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips de días
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(horarios.length, (i) {
              final isActive = i == _selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF0056D2),
                                Color(0xFF007AFF),
                              ],
                            )
                          : null,
                      color: isActive
                          ? null
                          : (widget.isDark
                              ? AppColors.darkElevated
                              : const Color(0xFFF0F2F5)),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      horarios[i].dia,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : AppColors.textSecondaryC(widget.isDark),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Detalle del turno seleccionado
        if (selected != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.darkElevated
                  : const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 16, color: Color(0xFF007AFF)),
                    const SizedBox(width: 8),
                    Text(
                      selected.rango,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF007AFF),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  selected.turno,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryC(widget.isDark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estados vacío / error / cargando
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2.5),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Cargando médicos…',
              style: TextStyle(
                  color: AppColors.textSecondaryC(isDark), fontSize: 14),
            ),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  const _ErrorView(
      {required this.message, required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 48, color: AppColors.textTertiaryC(isDark)),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondaryC(isDark), fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.lg),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  final bool isDark;
  final bool esBusqueda;

  const _EmptyView({required this.isDark, this.esBusqueda = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                esBusqueda
                    ? Icons.search_off_rounded
                    : Icons.event_busy_rounded,
                size: 48,
                color: AppColors.textTertiaryC(isDark),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                esBusqueda
                    ? 'Sin resultados para esa búsqueda.'
                    : 'Sin médicos disponibles para esta fecha.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondaryC(isDark), fontSize: 14),
              ),
            ],
          ),
        ),
      );
}
