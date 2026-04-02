import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/models/reserva_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/session/user_session.dart';
import '../../../core/widgets/appointment_card.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/beneficiary_selector_modal.dart';
import '../../../core/models/beneficiary_model.dart';
import 'detalle_cita_screen.dart';

class ReservasScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;

  const ReservasScreen({super.key, this.refreshNotifier});

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
  final List<String> _statusFilters = ['Todos', 'Pendiente', 'Completado', 'Falta', 'Cancelado'];
  String _activeStatusFilter = 'Todos';
  int _displayLimit = 10;

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
          _errorMessage = 'No se pudo cargar el historial de reservas.';
          _isLoading = false;
        }
      });
    }
  }

  void _openDetalle(ReservaModel reserva) {
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => DetalleCitaScreen(reserva: reserva),
      ),
    );
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

  void _onCancelAppointment(ReservaModel reserva) {
    if (!reserva.canDownloadPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede cancelar esta cita: faltan datos de referencia.')),
      );
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cancelar Cita'),
        content: Text('¿Está seguro que desea cancelar su cita de ${reserva.specialty} con el Dr. ${reserva.doctorName}?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('No, mantener'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sí, cancelar'),
            onPressed: () async {
              Navigator.pop(context);
              
              // Mostrar indicador de carga
              showCupertinoDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CupertinoActivityIndicator(radius: 15)),
              );

              try {
                final success = await _service.cancelarCita(
                  gestion: reserva.gestion!,
                  idins: reserva.idins!,
                  idsuc: reserva.idsuc!,
                  idtran: reserva.idtran!,
                  dr: reserva.dr!,
                );

                if (!mounted) return;
                Navigator.pop(context); // Quitar loader

                if (success) {
                  setState(() {
                    final index = _history.indexOf(reserva);
                    if (index != -1) {
                      _history[index] = _history[index].copyWith(status: 'Cancelado');
                    }
                  });
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Cita Cancelada'),
                      content: const Text('Su cita médica ha sido cancelada exitosamente.'),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text('Entendido'),
                          onPressed: () {
                            Navigator.pop(context);
                            _fetchReservas(); // Refrescar historial completo en segundo plano
                          },
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context); // Quitar loader
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

    final filtered = _history.where((r) {
      if (_activeStatusFilter == 'Todos') return true;
      return r.status.toLowerCase() == _activeStatusFilter.toLowerCase();
    }).toList();

    final visible = filtered.take(_displayLimit).toList();
    final hasMore = filtered.length > visible.length;

    if (_history.isEmpty && !_isLoading) {
      return _emptyState(context, isDark);
    }

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
                color: AppColors.cardBorder(isDark).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          CupertinoSliverRefreshControl(onRefresh: () async { _fetchReservas(); }),
          
          if (UserSession.currentUser.isTitular && UserSession.currentUser.beneficiaries.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildBeneficiarySelector(isDark),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeSlideIn(
                  duration: const Duration(milliseconds: 350),
                  child: _buildSummaryBar(
                      context, _completedCount, _missedCount, isDark),
                ),
                const SizedBox(height: 16),
                _buildFilterBar(isDark),
                FadeSlideIn(
                  duration: AppDurations.slow,
                  delay: const Duration(milliseconds: 100),
                  offsetY: 10,
                  child: _sectionHeader(
                      context, 'HISTORIAL DE ATENCIONES', filtered.length),
                ),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.only(bottom: 120, left: 12, right: 12),
            sliver: SliverList.builder(
              itemCount: visible.length + (hasMore ? 1 : (_currentPage < _totalPages ? 1 : 0)),
              itemBuilder: (context, index) {
                if (index == visible.length && hasMore) {
                  final remaining = filtered.length - _displayLimit;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                final isPending = reserva.status == 'Pendiente';
                final canCancel = isPending && reserva.canDownloadPdf;

                Widget card = AppointmentCard(
                  appointment: reserva,
                  onTap: () => _openDetalle(reserva),
                );

                if (canCancel) {
                  card = Dismissible(
                    key: ValueKey('cancel-${reserva.codigoReserva ?? index}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      _onCancelAppointment(reserva);
                      return false; // No dismiss automático, lo maneja el diálogo
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: EdgeInsets.symmetric(horizontal: ResponsiveData.of(context).isSmallPhone ? 8 : 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.destructiveRed.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.delete,
                            color: CupertinoColors.destructiveRed,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cancelar',
                            style: TextStyle(
                              color: CupertinoColors.destructiveRed,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: card,
                  );
                }

                if (shouldAnimate) {
                  return Column(
                    children: [
                      FadeSlideIn(delay: Duration(milliseconds: 200 + (index * 50)), duration: AppDurations.normal, offsetY: 10, child: card),
                      if (index < visible.length - 1) const SizedBox(height: 10),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      card,
                      if (index < visible.length - 1) const SizedBox(height: 10),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
          borderRadius: BorderRadius.circular(20),
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
            fontSize: 14,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.group_solid, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Viendo reservas de:', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryC(isDark))),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimaryC(isDark))),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_down, size: 18, color: AppColors.textTertiaryC(isDark)),
          ],
        ),
      ),
    );
  }

  /// Summary bar: Completados / Faltas.
  Widget _buildSummaryBar(
      BuildContext context, int completed, int missed, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
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
            style: AppTypography.displayMedium.copyWith(
              color: color,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
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
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryC(isDark),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
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
                    const SizedBox(height: 24),
                    Text(
                      _selectedBeneficiary != null && !_selectedBeneficiary!.isTitular
                          ? '${_selectedBeneficiary!.fullName}\nno tiene atenciones registradas'
                          : 'No tiene atenciones registradas',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondaryC(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'El historial de atenciones aparecerá aquí',
                      style: TextStyle(
                        fontSize: 14,
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

