import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/animations/animated_status_badge.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/beneficiary_selector_modal.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/utils/error_mapper.dart';
import 'detalle_cita_screen.dart';

class ReservasScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final ({int idtran, int dr})? lastBookingIds;

  const ReservasScreen({super.key, this.refreshNotifier, this.lastBookingIds});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  final _service = ProgramacionService();

  List<ReservaModel> _history = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  int _currentPage = 1;
  int _totalPages = 1;
  int _totalElements = 0;
  static const _pageSize = 20;

  BeneficiaryModel? _selectedBeneficiary;
  final List<String> _statusFilters = ['Todos', 'Completado', 'Falta', 'Cancelado'];
  String _activeStatusFilter = 'Todos';
  int _displayLimit = 10;

  bool _isCancellingLatest = false;

  @override
  void initState() {
    super.initState();
    _fetchReservas();
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    super.dispose();
  }

  void _onRefreshRequested() {
    _fetchReservas();
  }

  Future<void> _fetchReservas({bool loadMore = false}) async {
    if (!mounted) return;

    if (loadMore) {
      if (_currentPage >= _totalPages || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final idper = int.tryParse(_selectedBeneficiary?.id ?? UserSession.currentUser.id) ?? 0;
      final page = loadMore ? _currentPage + 1 : 1;
      final result = await _service.getHistorialCitas(
        idper,
        pagina: page,
        cantidad: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _history.addAll(result.reservas);
          _isLoadingMore = false;
        } else {
          _history = result.reservas;
          _isLoading = false;
        }

        _history.sort((a, b) {
          final aP = a.status == 'Pendiente' ? 1 : 0;
          final bP = b.status == 'Pendiente' ? 1 : 0;
          if (aP != bP) return bP.compareTo(aP);

          final dC = b.date.compareTo(a.date);
          if (dC != 0) return dC;
          return b.time.compareTo(a.time);
        });

        _currentPage = page;
        _totalPages = result.totalPages;
        _totalElements = result.totalElements;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          _errorMessage = ErrorMapper.message(e, context: ErrorContext.cargarHistorial);
          _isLoading = false;
        }
      });
    }
  }

  void _openDetalle(ReservaModel reserva) async {
    final wasCancelled = await Navigator.push<bool>(
      context,
      AppPageRoute(
        builder: (_) => DetalleCitaScreen(reserva: reserva),
      ),
    );
    if (wasCancelled == true && mounted) {
      setState(() {
        final index = _history.indexWhere((r) => r.id == reserva.id ||
            (r.idtran == reserva.idtran && r.dr == reserva.dr));
        if (index != -1) {
          _history[index] = _history[index].copyWith(status: 'Cancelado');
          _history.sort((a, b) {
            final aP = a.status == 'Pendiente' ? 1 : 0;
            final bP = b.status == 'Pendiente' ? 1 : 0;
            if (aP != bP) return bP.compareTo(aP);
            final dC = b.date.compareTo(a.date);
            if (dC != 0) return dC;
            return b.time.compareTo(a.time);
          });
        }
      });
    }
  }

  Future<void> _onChangeBeneficiary() async {
    final selected = await BeneficiarySelectorModal.show(
      context: context,
      beneficiaries: UserSession.currentUser.beneficiaries,
      currentId: _selectedBeneficiary?.id,
    );
    if (selected != null && mounted) {
      setState(() => _selectedBeneficiary = selected);
      _fetchReservas();
    }
  }

  void _onCancelLatestAppointment(ReservaModel reserva) {
    if (!reserva.canDownloadPdf) return;

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cancelar Cita'),
        content: Text('¿Está seguro que desea cancelar su cita de ${reserva.specialty} con el Dr. ${reserva.doctorName}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('No, mantener'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sí, cancelar'),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isCancellingLatest = true);

              try {
                final success = await _service.cancelarCita(
                  gestion: reserva.gestion!,
                  idins: reserva.idins!,
                  idsuc: reserva.idsuc!,
                  idtran: reserva.idtran!,
                  dr: reserva.dr!,
                );

                if (!mounted) return;
                setState(() => _isCancellingLatest = false);

                if (success) {
                  setState(() {
                    final index = _history.indexWhere((r) => r.id == reserva.id ||
                        (r.idtran == reserva.idtran && r.dr == reserva.dr));
                    if (index != -1) {
                      _history[index] = _history[index].copyWith(status: 'Cancelado', estadoCancelacion: '1');
                      _history.sort((a, b) {
                        final aP = a.status == 'Pendiente' ? 1 : 0;
                        final bP = b.status == 'Pendiente' ? 1 : 0;
                        if (aP != bP) return bP.compareTo(aP);
                        final dC = b.date.compareTo(a.date);
                        if (dC != 0) return dC;
                        return b.time.compareTo(a.time);
                      });
                    }
                  });
                  if (!mounted) return;
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx2) => CupertinoAlertDialog(
                      title: const Text('Cita Cancelada'),
                      content: const Text('Su cita médica ha sido cancelada exitosamente.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Entendido'),
                          onPressed: () => Navigator.pop(ctx2),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                setState(() => _isCancellingLatest = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al cancelar: $e'), backgroundColor: AppColors.error),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// La última reserva es la primera con estadoCancelacion == "0" (no cancelada, activa).
  ReservaModel? get _latestPending {
    final match = widget.lastBookingIds;
    if (match != null) {
      final found = _history.where((r) =>
          r.idtran == match.idtran && r.dr == match.dr && r.estadoCancelacion == '0');
      if (found.isNotEmpty) return found.first;
    }
    final pending = _history.where((r) => r.estadoCancelacion == '0' && r.status == 'Pendiente');
    return pending.isNotEmpty ? pending.first : null;
  }

  int get _completedCount =>
      _history.where((a) => a.status == 'Completado').length;

  int get _missedCount =>
      _history.where((a) => a.status == 'Falta').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: const AppStateWidget.loading(),
      );
    }

    if (_errorMessage != null) {
      return CupertinoPageScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: AppStateWidget.error(
          title: 'Error',
          message: _errorMessage!,
          onRetry: _fetchReservas,
        ),
      );
    }

    if (_history.isEmpty && !_isLoading) {
      return _emptyState(context, isDark);
    }

    final latest = _latestPending;

    final filtered = _history.where((r) {
      if (_activeStatusFilter == 'Todos') return true;
      return r.status.toLowerCase() == _activeStatusFilter.toLowerCase();
    }).toList();

    // Quitar la última pendiente de la lista filtrada si se muestra arriba
    final historyList = latest != null && _activeStatusFilter == 'Todos'
        ? filtered.where((r) => !(r.idtran == latest.idtran && r.dr == latest.dr && r.id == latest.id)).toList()
        : filtered;

    final visible = historyList.take(_displayLimit).toList();
    final hasMore = historyList.length > visible.length;

    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text('Mis Reservas',
                    style: TextStyle(color: AppColors.textPrimaryC(isDark))),
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
              CupertinoSliverRefreshControl(onRefresh: () async { _fetchReservas(); }),

              if (UserSession.currentUser.isTitular && UserSession.currentUser.beneficiaries.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, 0),
                    child: _buildBeneficiarySelector(isDark),
                  ),
                ),

              // ── Tarjeta destacada: última reserva pendiente ──
              if (latest != null && _activeStatusFilter == 'Todos')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, 0),
                    child: FadeSlideIn(
                      duration: const Duration(milliseconds: 400),
                      offsetY: 15,
                      child: _buildLatestCard(latest, isDark, r),
                    ),
                  ),
                ),

              // ── Resumen + Filtros ──
              SliverPadding(
                padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, r.spaceSm),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    FadeSlideIn(
                      duration: const Duration(milliseconds: 350),
                      child: _buildSummaryBar(
                          context, _completedCount, _missedCount, isDark),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    _buildFilterBar(isDark),
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      delay: const Duration(milliseconds: 100),
                      offsetY: 10,
                      child: _sectionHeader(
                          context, 'HISTORIAL DE ATENCIONES', historyList.length),
                    ),
                  ]),
                ),
              ),

              // ── Lista del historial (solo informativo) ──
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: r.spaceXl, horizontal: r.paddingH),
                    child: Center(
                      child: Text(
                        'No hay registros con este filtro',
                        style: TextStyle(
                          color: AppColors.textTertiaryC(isDark),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(bottom: r.navBarBottomSpace, left: r.paddingH, right: r.paddingH),
                  sliver: SliverList.builder(
                    itemCount: visible.length + (hasMore ? 1 : (_currentPage < _totalPages ? 1 : 0)),
                    itemBuilder: (context, index) {
                      if (index == visible.length && hasMore) {
                        final remaining = historyList.length - _displayLimit;
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                          child: Center(
                            child: CupertinoButton(
                              onPressed: () => setState(() => _displayLimit += 10),
                              child: Text(
                                'Mostrar más ($remaining restantes)',
                                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentForTheme(isDark)),
                              ),
                            ),
                          ),
                        );
                      } else if (index == visible.length && _currentPage < _totalPages) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: context.r.spaceMd),
                          child: Center(
                            child: _isLoadingMore
                                ? const CupertinoActivityIndicator()
                                : CupertinoButton(
                                    onPressed: () => _fetchReservas(loadMore: true),
                                    child: Text('Cargar más historial', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentForTheme(isDark))),
                                  ),
                          ),
                        );
                      }

                      final reserva = visible[index];
                      final shouldAnimate = index < 5;

                      Widget card = _buildHistoryItem(reserva, isDark, r);

                      if (shouldAnimate) {
                        return FadeSlideIn(
                          delay: Duration(milliseconds: 200 + (index * 50)),
                          duration: AppDurations.normal,
                          offsetY: 10,
                          child: card,
                        );
                      }
                      return card;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TARJETA DESTACADA — última reserva pendiente con acciones
  // ══════════════════════════════════════════════════════════════

  Widget _buildLatestCard(ReservaModel reserva, bool isDark, AppResponsive r) {
    final accentColor = const Color(0xFF2563EB);

    return GestureDetector(
      onTap: () => _openDetalle(reserva),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F1B2D), const Color(0xFF162033)]
                : [const Color(0xFFF0F6FF), const Color(0xFFE8F0FE)],
          ),
          borderRadius: BorderRadius.circular(r.cardRadius + 4),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.4 : 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.10),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado con etiqueta ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: r.cardPadding, vertical: r.spaceSm + 2),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(r.cardRadius + 3),
                  topRight: Radius.circular(r.cardRadius + 3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.clock_fill, size: 14, color: Colors.white),
                  SizedBox(width: r.spaceXs),
                  Text(
                    'PRÓXIMA CITA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: r.sectionLabelSize,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VIGENTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Contenido ──
            Padding(
              padding: EdgeInsets.all(r.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Especialidad
                  Text(
                    reserva.specialty,
                    style: context.texts.displayLarge.copyWith(
                      color: AppColors.textPrimaryC(isDark),
                      fontSize: r.isSmallPhone ? 18 : 20,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.spaceXs),

                  // Doctor
                  Row(
                    children: [
                      Icon(CupertinoIcons.person_fill, size: 14,
                          color: accentColor.withValues(alpha: 0.7)),
                      SizedBox(width: r.spaceXs),
                      Expanded(
                        child: Text(
                          'Dr. ${reserva.doctorName}',
                          style: context.texts.bodyMedium.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  if (reserva.patientName.isNotEmpty) ...[
                    SizedBox(height: r.spaceXs),
                    Row(
                      children: [
                        Icon(CupertinoIcons.person_2_fill, size: 14,
                            color: AppColors.textTertiaryC(isDark)),
                        SizedBox(width: r.spaceXs),
                        Expanded(
                          child: Text(
                            'Paciente: ${reserva.patientName}',
                            style: context.texts.bodySmall.copyWith(
                              color: AppColors.textSecondaryC(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: r.spaceMd),

                  // ── Fecha / Hora / Hospital ──
                  Container(
                    padding: EdgeInsets.all(r.spaceSm + 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(r.radiusSm + 2),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : accentColor.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Fecha
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(CupertinoIcons.calendar, size: 16, color: accentColor),
                              ),
                              SizedBox(width: r.spaceXs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reserva.formattedDate,
                                      style: context.texts.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimaryC(isDark),
                                      ),
                                    ),
                                    if (reserva.time.isNotEmpty)
                                      Text(
                                        reserva.time,
                                        style: context.texts.bodySmall.copyWith(
                                          color: AppColors.textSecondaryC(isDark),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (reserva.hospital.isNotEmpty) ...[
                          Container(width: 0.5, height: 32, color: AppColors.dividerC(isDark)),
                          SizedBox(width: r.spaceSm),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.local_hospital_outlined, size: 16, color: accentColor),
                                ),
                                SizedBox(width: r.spaceXs),
                                Expanded(
                                  child: Text(
                                    reserva.hospital,
                                    style: context.texts.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondaryC(isDark),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: r.spaceMd),

                  // ── Botones de acción ──
                  Row(
                    children: [
                      // Botón Ver detalle
                      Expanded(
                        child: CupertinoButton(
                          padding: EdgeInsets.symmetric(vertical: r.spaceSm + 2),
                          color: accentColor,
                          borderRadius: BorderRadius.circular(r.radiusSm + 2),
                          onPressed: () => _openDetalle(reserva),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.doc_text_search, size: 16, color: Colors.white),
                              SizedBox(width: r.spaceXs),
                              Text(
                                'Ver Detalle',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.isSmallPhone ? 13 : 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Botón Cancelar (solo si estadoCancelacion == "0")
                      if (reserva.canCancel) ...[
                        SizedBox(width: r.spaceSm),
                        CupertinoButton(
                          padding: EdgeInsets.symmetric(horizontal: r.spaceMd, vertical: r.spaceSm + 2),
                          color: isDark
                              ? CupertinoColors.destructiveRed.withValues(alpha: 0.15)
                              : CupertinoColors.destructiveRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(r.radiusSm + 2),
                          onPressed: _isCancellingLatest ? null : () => _onCancelLatestAppointment(reserva),
                          child: _isCancellingLatest
                              ? const CupertinoActivityIndicator()
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.xmark_circle_fill, size: 16,
                                        color: CupertinoColors.destructiveRed),
                                    SizedBox(width: r.spaceXs),
                                    Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: CupertinoColors.destructiveRed,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.isSmallPhone ? 13 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ITEM DE HISTORIAL — solo informativo, sin acciones
  // ══════════════════════════════════════════════════════════════

  Widget _buildHistoryItem(ReservaModel reserva, bool isDark, AppResponsive r) {
    final statusColor = _statusColor(reserva.status);

    return Padding(
      padding: EdgeInsets.only(bottom: r.spaceSm),
      child: OptimizedPressButton(
        onTap: () => _openDetalle(reserva),
        scaleDown: 0.98,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: r.cardPadding, vertical: r.spaceSm + 4),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(r.cardRadius),
            border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
            boxShadow: AppColors.cardShadowFor(isDark),
          ),
          child: Row(
            children: [
              // Indicador de color del estado (barra lateral)
              Container(
                width: 3,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: r.spaceSm),

              // Info principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reserva.specialty,
                      style: context.texts.titleLarge.copyWith(
                        color: AppColors.textPrimaryC(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      reserva.doctorName,
                      style: context.texts.bodySmall.copyWith(
                        color: AppColors.textSecondaryC(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: r.spaceXs),
                    Row(
                      children: [
                        Icon(CupertinoIcons.calendar, size: 12,
                            color: AppColors.textTertiaryC(isDark)),
                        SizedBox(width: 4),
                        Text(
                          reserva.formattedDate,
                          style: context.texts.labelSmall.copyWith(
                            color: AppColors.textTertiaryC(isDark),
                          ),
                        ),
                        if (reserva.time.isNotEmpty) ...[
                          SizedBox(width: r.spaceSm),
                          Icon(CupertinoIcons.clock, size: 12,
                              color: AppColors.textTertiaryC(isDark)),
                          SizedBox(width: 4),
                          Text(
                            reserva.time,
                            style: context.texts.labelSmall.copyWith(
                              color: AppColors.textTertiaryC(isDark),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: r.spaceXs),

              // Badge de estado (no mostrar para Pendiente)
              if (reserva.status != 'Pendiente')
                AnimatedStatusBadge.fromStatus(reserva.status),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completado': return AppColors.accent;
      case 'Falta': return const Color(0xFF9333EA);
      case 'Pendiente': return const Color(0xFF2563EB);
      case 'Cancelado': return AppColors.textSecondary;
      default: return AppColors.textSecondary;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  COMPONENTES AUXILIARES
  // ══════════════════════════════════════════════════════════════

  Widget _buildFilterBar(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        separatorBuilder: (_, __) => SizedBox(width: context.r.spaceSm),
        itemBuilder: (_, i) => _buildStatusChip(_statusFilters[i], isDark),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool isDark) {
    final isActive = _activeStatusFilter == label;
    return GestureDetector(
      onTap: () => setState(() {
        _activeStatusFilter = label;
        _displayLimit = 10;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : (isDark ? AppColors.darkElevated : AppColors.background),
          borderRadius: BorderRadius.circular(context.r.chipRadius),
          border: Border.all(
            color: isActive ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondaryC(isDark),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBeneficiarySelector(bool isDark) {
    final label = _selectedBeneficiary == null || _selectedBeneficiary!.isTitular
        ? 'Yo (Titular)'
        : _selectedBeneficiary!.relationship;

    return GestureDetector(
      onTap: _onChangeBeneficiary,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkElevated : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.r.spaceSm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.group_solid, color: AppColors.primary, size: 20),
            ),
            SizedBox(width: context.r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Viendo reservas de:', style: context.texts.bodySmall.copyWith(color: AppColors.textSecondaryC(isDark))),
                  SizedBox(height: context.r.spaceXs),
                  Text(label, style: context.texts.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimaryC(isDark))),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_down, size: 18, color: AppColors.textTertiaryC(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(
      BuildContext context, int completed, int missed, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.r.tileHorizontalPad, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(context.r.cardRadius),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
            color: AppColors.cardBorder(isDark),
            width: 0.5),
      ),
      child: Row(
        children: [
          _summaryChip(
              '$completed', 'Completados', AppColors.accent,
              isDark: isDark),
          Container(
              width: 0.5,
              height: 28,
              color: AppColors.dividerC(isDark)),
          _summaryChip(
            '$missed',
            missed == 1 ? 'Falta' : 'Faltas',
            isDark ? AppColors.white : const Color(0xFF9333EA),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String count, String label, Color color,
      {required bool isDark}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            count,
            style: context.texts.displayLarge.copyWith(
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: context.texts.labelSmall.copyWith(
              color: AppColors.textSecondaryC(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: isDark ? AppColors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(context.r.spaceXs),
            ),
          ),
          SizedBox(width: context.r.spaceSm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryC(isDark),
                letterSpacing: 1.0,
              ),
            ),
          ),
          SizedBox(width: context.r.spaceSm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.r.radiusSm),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark) {
    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text('Mis Reservas',
                style: TextStyle(color: AppColors.textPrimaryC(isDark))),
            backgroundColor: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.92)
                : AppColors.white.withValues(alpha: 0.92),
            border: Border(
              bottom: BorderSide(
                color:
                    AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          SliverFillRemaining(
            child: Center(
              child: FadeSlideIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 64,
                      color: AppColors.textTertiaryC(isDark)
                          .withValues(alpha: 0.3),
                    ),
                    SizedBox(height: context.r.spaceLg),
                    Text(
                      _selectedBeneficiary != null && !_selectedBeneficiary!.isTitular
                          ? '${_selectedBeneficiary!.fullName}\nno tiene atenciones registradas'
                          : 'No tiene atenciones registradas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    SizedBox(height: context.r.spaceMd),
                    Text(
                      'El historial de atenciones aparecerá aquí',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiaryC(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

