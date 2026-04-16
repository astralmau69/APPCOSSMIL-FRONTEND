import 'dart:convert';
import 'dart:typed_data';
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
import '../../../core/services/notification_service.dart';
import 'detalle_cita_screen.dart';
import '../widgets/doctor_rating_modal.dart';

class ReservasScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final ({int idtran, int dr})? lastBookingIds;
  /// idper del paciente de la última reserva confirmada.
  /// Usado para refrescar la lista en la vista correcta del beneficiario.
  final String? lastBookedIdper;

  const ReservasScreen({super.key, this.refreshNotifier, this.lastBookingIds, this.lastBookedIdper});

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
  static const _pageSize = 20;
  // Tamaño grande para la carga inicial: trae todo el historial en un solo request
  // independientemente del orden (ASC/DESC) que use el backend.
  static const _initialPageSize = 999;

  BeneficiaryModel? _selectedBeneficiary;

  /// Caché local del grupo familiar. Se carga desde UserSession y se refresca
  /// desde la API cuando solo hay el titular, igual que hace RegionalScreen.
  /// Usar ESTO en lugar de UserSession.currentUser.beneficiaries directamente
  /// para evitar la race condition que hace desaparecer el selector.
  List<BeneficiaryModel> _beneficiaries = [];

  final List<String> _statusFilters = ['Todos', 'Completado', 'Falta', 'Cancelado'];
  String _activeStatusFilter = 'Todos';
  int _displayLimit = 10;

  bool _isCancellingLatest = false;
  Uint8List? _latestDoctorPhotoBytes;

  /// idsuc → nombre completo del hospital (cargado desde la API de regionales)
  Map<int, String> _hospitalNames = {};

  /// IDs de reservas que fueron ofrecidas para calificación pero el usuario
  /// las omitió. Formato: "${idtran}_${dr}". Usadas para mostrar el botón.
  Set<String> _pendingRatings = {};

  @override
  void initState() {
    super.initState();
    // Carga inicial del caché local — puede ser solo [titular] en este momento.
    _beneficiaries = List.from(UserSession.currentUser.beneficiaries);
    _fetchReservas();
    _fetchHospitalNames();
    _loadBeneficiaries(); // refresca en background si la lista aún está incompleta
    widget.refreshNotifier?.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequested);
    super.dispose();
  }

  Future<void> _onRefreshRequested() async {
    await _loadBeneficiaries();

    // Si viene de una reserva recién confirmada, seleccionar automáticamente
    // al beneficiario correcto antes de pedir el historial.
    final bookedIdper = widget.lastBookedIdper;
    if (bookedIdper != null && UserSession.currentUser.isTitular) {
      // Titular reservando para un familiar: apuntar la vista al paciente reservado.
      final match = _beneficiaries.where((b) => b.id == bookedIdper).firstOrNull;
      if (match != null && mounted) {
        setState(() => _selectedBeneficiary = match.isTitular ? null : match);
      }
    } else if (bookedIdper != null && !UserSession.currentUser.isTitular) {
      // Cuenta beneficiaria: usar el idper capturado directamente para el fetch.
      _fetchReservasForIdper(bookedIdper);
      return;
    }

    _fetchReservas();
  }

  /// Garantiza que `_beneficiaries` tenga el grupo familiar completo.
  ///
  /// Si la sesión ya tiene 2+ miembros, los usa directamente.
  /// Si solo hay el titular (o la lista está vacía), va al API igual que
  /// hace [_tryEnterBookingTab] en TabShell para el flujo de reserva.
  Future<void> _loadBeneficiaries() async {
    if (!UserSession.currentUser.isTitular) return;

    final fromSession = UserSession.currentUser.beneficiaries;
    if (fromSession.length > 1) {
      if (mounted) setState(() => _beneficiaries = List.from(fromSession));
      return;
    }

    // Solo titular o vacío → pedir al API
    try {
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
      if (idper == 0) return;
      final fresh = await _service.getGrupoFamiliar(idper);
      if (!mounted) return;
      if (fresh.isNotEmpty) {
        // Actualizar sesión global y caché local
        UserSession.currentUser = UserSession.currentUser.copyWith(beneficiaries: fresh);
        setState(() => _beneficiaries = List.from(fresh));
      } else if (fromSession.isNotEmpty) {
        setState(() => _beneficiaries = List.from(fromSession));
      }
    } catch (_) {
      if (fromSession.isNotEmpty && mounted) {
        setState(() => _beneficiaries = List.from(fromSession));
      }
    }
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
      // Carga inicial con tamaño grande: el backend devuelve TODO el historial en
      // un solo request (independientemente del orden ASC/DESC del servidor).
      final cantidad = loadMore ? _pageSize : _initialPageSize;
      final result = await _service.getHistorialCitas(
        idper,
        pagina: page,
        cantidad: cantidad,
      );

      // Red de seguridad: si el backend capó la respuesta y reporta más páginas,
      // traer también la última para capturar las citas más recientes.
      List<ReservaModel> fetched = result.reservas;
      final fetchedTotalPages = result.totalPages > 0 ? result.totalPages : 1;
      if (!loadMore && fetchedTotalPages > 1) {
        try {
          final lastPage = await _service.getHistorialCitas(
            idper,
            pagina: fetchedTotalPages,
            cantidad: _pageSize,
          );
          if (!mounted) return;
          final seen = result.reservas
              .map((r) => '${r.idtran}_${r.dr}_${r.id}')
              .toSet();
          final extra = lastPage.reservas
              .where((r) => !seen.contains('${r.idtran}_${r.dr}_${r.id}'))
              .toList();
          if (extra.isNotEmpty) fetched = [...result.reservas, ...extra];
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _history.addAll(result.reservas);
          _isLoadingMore = false;
        } else {
          _history = fetched;
          _isLoading = false;
        }

        _history.sort((a, b) {
          final aP = a.status == 'Pendiente' ? 0 : 1;
          final bP = b.status == 'Pendiente' ? 0 : 1;
          if (aP != bP) return aP.compareTo(bP);
          if (a.status == 'Pendiente') {
            final dC = a.date.compareTo(b.date);
            if (dC != 0) return dC;
            return a.time.compareTo(b.time);
          }
          final dC = b.date.compareTo(a.date);
          if (dC != 0) return dC;
          return b.time.compareTo(a.time);
        });

        _currentPage = page;
        _totalPages = fetchedTotalPages;
      });

      // Fetch foto del médico para la primera ficha vigente (silencioso)
      if (!loadMore) {
        final vigentes = _allPendingVigentes;
        if (vigentes.isNotEmpty) _fetchLatestDoctorPhoto(vigentes.first);
      }

      // Cargar estado de botones "Calificar" para el historial.
      if (!loadMore && mounted) _loadPendingRatings();

      // Auto-prompt de nueva reserva deshabilitado.
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

  /// Variante de [_fetchReservas] que usa un idper explícito en lugar del
  /// `_selectedBeneficiary` actual. Usada para refrescar al paciente recién reservado
  /// cuando es una cuenta beneficiaria (no titular).
  Future<void> _fetchReservasForIdper(String idperStr) async {
    if (!mounted) return;
    final idper = int.tryParse(idperStr) ?? 0;
    if (idper == 0) { _fetchReservas(); return; }

    setState(() { _isLoading = true; _errorMessage = null; _currentPage = 1; });
    try {
      final result = await _service.getHistorialCitas(idper, pagina: 1, cantidad: _initialPageSize);
      if (!mounted) return;

      List<ReservaModel> fetched = result.reservas;
      final fetchedTotalPages = result.totalPages > 0 ? result.totalPages : 1;
      if (fetchedTotalPages > 1) {
        try {
          final lastPage = await _service.getHistorialCitas(
              idper, pagina: fetchedTotalPages, cantidad: _pageSize);
          if (!mounted) return;
          final seen = result.reservas
              .map((r) => '${r.idtran}_${r.dr}_${r.id}')
              .toSet();
          final extra = lastPage.reservas
              .where((r) => !seen.contains('${r.idtran}_${r.dr}_${r.id}'))
              .toList();
          if (extra.isNotEmpty) fetched = [...result.reservas, ...extra];
        } catch (_) {}
      }

      setState(() {
        _history = fetched;
        _isLoading = false;
        _history.sort((a, b) {
          final aP = a.status == 'Pendiente' ? 0 : 1;
          final bP = b.status == 'Pendiente' ? 0 : 1;
          if (aP != bP) return aP.compareTo(bP);
          if (a.status == 'Pendiente') {
            final dC = a.date.compareTo(b.date);
            if (dC != 0) return dC;
            return a.time.compareTo(b.time);
          }
          final dC = b.date.compareTo(a.date);
          if (dC != 0) return dC;
          return b.time.compareTo(a.time);
        });
        _currentPage = 1;
        _totalPages = fetchedTotalPages;
      });
      final vigentes = _allPendingVigentes;
      if (vigentes.isNotEmpty) _fetchLatestDoctorPhoto(vigentes.first);
      if (mounted) _loadPendingRatings();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorMapper.message(e, context: ErrorContext.cargarHistorial);
        _isLoading = false;
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
      _fetchReservas();
    }
  }

  Future<void> _onChangeBeneficiary() async {
    final selected = await BeneficiarySelectorModal.show(
      context: context,
      beneficiaries: _beneficiaries,
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
        title: const Text('Cancelar Cita Médica'),
        content: Text('¿Está seguro que desea cancelar su cita médica de ${reserva.specialty} con el Dr. ${reserva.doctorName}?'),
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
                  // Cancelar notificaciones programadas para esta cita
                  if (reserva.idtran != null) {
                    try {
                      await NotificationService.cancelAppointmentReminders(
                        reserva.idtran.toString(),
                      );
                    } catch (_) {}
                  }
                  if (!mounted) return;
                  // Recargar desde el API para reflejar el estado real
                  _fetchReservas();
                  showCupertinoDialog(
                    context: context,
                    builder: (ctx2) => CupertinoAlertDialog(
                      title: const Text('Cita médica cancelada'),
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
                final msg = e.toString().replaceFirst('Exception: ', '');
                showCupertinoDialog(
                  context: context,
                  builder: (ctx2) => CupertinoAlertDialog(
                    title: const Text('No se pudo cancelar'),
                    content: Text(msg),
                    actions: [
                      CupertinoDialogAction(
                        child: const Text('Entendido'),
                        onPressed: () => Navigator.pop(ctx2),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Fichas pendientes cuya fecha de cita es hoy o en el futuro (comparación
  /// de fecha pura, sin hora). Citas Pendiente de días pasados que el sistema
  /// aún no procesó no se muestran en grande — van solo al historial.
  List<ReservaModel> get _allPendingVigentes {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    final vigentes = _history.where((r) {
      if (r.estadoCancelacion != '0' || r.status != 'Pendiente') return false;
      final apptDate = r.appointmentDate;
      // Si no se puede parsear la fecha, mostrar por si acaso
      if (apptDate == null) return true;
      // Mostrar solo si la fecha de la cita es hoy o posterior
      return !apptDate.isBefore(todayDate);
    }).toList();

    // Ascendente: la cita más próxima (o recién reservada para mañana) aparece primero.
    vigentes.sort((a, b) {
      final dC = a.date.compareTo(b.date);
      if (dC != 0) return dC;
      return a.time.compareTo(b.time);
    });

    final match = widget.lastBookingIds;
    if (match != null) {
      final idx = vigentes.indexWhere((r) => r.idtran == match.idtran && r.dr == match.dr);
      if (idx > 0) {
        final promoted = vigentes.removeAt(idx);
        vigentes.insert(0, promoted);
      }
    }
    return vigentes;
  }

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

    final allPending = _allPendingVigentes;

    final filtered = _history.where((r) {
      if (_activeStatusFilter == 'Todos') return true;
      return r.status.toLowerCase() == _activeStatusFilter.toLowerCase();
    }).toList();

    // Quitar todas las vigentes de la lista del historial (se muestran arriba)
    final pendingIds = allPending.map((r) => '${r.idtran}_${r.dr}_${r.id}').toSet();
    final historyList = allPending.isNotEmpty && _activeStatusFilter == 'Todos'
        ? filtered.where((r) => !pendingIds.contains('${r.idtran}_${r.dr}_${r.id}')).toList()
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

              if (UserSession.currentUser.isTitular && _beneficiaries.length > 1)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, 0),
                    child: _buildBeneficiarySelector(isDark),
                  ),
                ),

              // ── Fichas vigentes: pendientes con fecha >= hoy ──
              if (allPending.isNotEmpty && _activeStatusFilter == 'Todos')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, 0),
                    child: Column(
                      children: allPending.asMap().entries.map((entry) {
                        final i = entry.key;
                        final reserva = entry.value;
                        return FadeSlideIn(
                          duration: const Duration(milliseconds: 400),
                          delay: Duration(milliseconds: i * 80),
                          offsetY: 15,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: i < allPending.length - 1 ? r.spaceMd : 0),
                            child: _buildLatestCard(reserva, isDark, r, isFirst: i == 0),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // ── Resumen + Filtros ──
              SliverPadding(
                padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceMd, r.paddingH, r.spaceSm),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildFilterBar(isDark),
                    FadeSlideIn(
                      duration: AppDurations.slow,
                      delay: const Duration(milliseconds: 100),
                      offsetY: 10,
                      child: _sectionHeader(
                          context, 'HISTORIAL DE ATENCIONES'),
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

  Widget _buildLatestCard(ReservaModel reserva, bool isDark, AppResponsive r, {bool isFirst = true}) {
    final accentColor = isFirst ? const Color(0xFF2563EB) : const Color(0xFF0891B2);

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
                    isFirst ? 'PRÓXIMA CITA MÉDICA' : 'CITA VIGENTE',
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
                  // Especialidad + doctor + paciente con foto del médico a la derecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  _buildPatientAvatar(22, isDark),
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
                          ],
                        ),
                      ),
                      // Foto del médico
                      SizedBox(width: r.spaceMd),
                      _buildLatestDoctorAvatar(reserva.doctorName, isDark),
                    ],
                  ),

                  SizedBox(height: r.spaceMd),

                  // ── Bloques de información separados ──
                  Column(
                    children: [
                      // Fecha
                      _buildDetailRow(
                        isDark: isDark,
                        accentColor: accentColor,
                        icon: CupertinoIcons.calendar,
                        label: 'FECHA',
                        value: reserva.formattedDate,
                        r: r,
                      ),
                      if (reserva.time.isNotEmpty) ...[
                        SizedBox(height: r.spaceSm),
                        // Hora
                        _buildDetailRow(
                          isDark: isDark,
                          accentColor: accentColor,
                          icon: CupertinoIcons.clock,
                          label: 'HORA',
                          value: reserva.formattedTime12h,
                          r: r,
                        ),
                      ],
                      if (reserva.consultorio != null && reserva.consultorio!.isNotEmpty) ...[
                        SizedBox(height: r.spaceSm),
                        // Consultorio
                        _buildDetailRow(
                          isDark: isDark,
                          accentColor: accentColor,
                          icon: Icons.meeting_room_outlined,
                          label: 'CONSULTORIO',
                          value: reserva.consultorio!,
                          r: r,
                        ),
                      ],
                      if (_hospitalLabel(reserva).isNotEmpty) ...[
                        SizedBox(height: r.spaceSm),
                        // Hospital
                        _buildDetailRow(
                          isDark: isDark,
                          accentColor: accentColor,
                          icon: Icons.local_hospital_outlined,
                          label: 'HOSPITAL',
                          value: _hospitalLabel(reserva),
                          r: r,
                        ),
                      ],
                    ],
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
                      // Botón Cancelar (solo si puede cancelar)
                      if (reserva.canCancel) ...[ 
                        SizedBox(width: r.spaceSm),
                        CupertinoButton(
                          padding: EdgeInsets.symmetric(horizontal: r.spaceMd, vertical: r.spaceSm + 2),
                          color: CupertinoColors.destructiveRed,
                          borderRadius: BorderRadius.circular(r.radiusSm + 2),
                          onPressed: _isCancellingLatest ? null : () => _onCancelLatestAppointment(reserva),
                          child: _isCancellingLatest
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(CupertinoIcons.xmark_circle_fill, size: 16,
                                        color: Colors.white),
                                    SizedBox(width: r.spaceXs),
                                    Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.isSmallPhone ? 13 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ] else if (reserva.estadoCancelacion == '0' &&
                          reserva.status != 'Cancelado' &&
                          reserva.isWithinTwoHoursOfAppointment) ...[
                        SizedBox(height: r.spaceSm),
                      ],
                    ],
                  ),
                  // Aviso de restricción de 2 horas (fuera del Row de botones)
                  if (reserva.estadoCancelacion == '0' &&
                      reserva.status != 'Cancelado' &&
                      reserva.isWithinTwoHoursOfAppointment) ...[
                    SizedBox(height: r.spaceSm),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: r.spaceMd, vertical: r.spaceXs + 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(r.radiusSm),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.exclamationmark_circle_fill,
                              size: 14, color: Color(0xFFB45309)),
                          SizedBox(width: r.spaceXs),
                          Expanded(
                            child: Text(
                              'No se puede cancelar con menos de 2 horas de anticipación.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    if (reserva.consultorio != null && reserva.consultorio!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 12,
                              color: AppColors.textTertiaryC(isDark)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              reserva.consultorio!,
                              style: context.texts.labelSmall.copyWith(
                                color: AppColors.textTertiaryC(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (reserva.time.isNotEmpty) ...[
                          SizedBox(width: r.spaceSm),
                          Icon(CupertinoIcons.clock, size: 12,
                              color: AppColors.textTertiaryC(isDark)),
                          SizedBox(width: 4),
                          Text(
                            reserva.formattedTime12h,
                            style: context.texts.labelSmall.copyWith(
                              color: AppColors.textTertiaryC(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_hospitalLabel(reserva).isNotEmpty) ...[
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_city_outlined, size: 12,
                              color: AppColors.textTertiaryC(isDark)),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _hospitalLabel(reserva),
                              style: context.texts.labelSmall.copyWith(
                                color: AppColors.textTertiaryC(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: r.spaceXs),

              // Columna derecha: badge de estado + botón calificar
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (reserva.status != 'Pendiente')
                    AnimatedStatusBadge.fromStatus(reserva.status),
                  // Botón calificar — solo si fue ofrecido y el usuario lo omitió.
                  if (_pendingRatings.contains('${reserva.idtran}_${reserva.dr}')) ...[
                    if (reserva.status != 'Pendiente') SizedBox(height: r.spaceXs),
                    GestureDetector(
                      onTap: () => DoctorRatingModal.showManual(context, reserva)
                          .then((_) => _loadPendingRatings()),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: r.spaceSm, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r.chipRadius),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.star_fill, size: 11, color: AppColors.primary),
                            SizedBox(width: 3),
                            Text(
                              'Calificar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
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


  /// Carga las reservas que fueron ofrecidas para calificación pero no calificadas.
  /// Actualiza [_pendingRatings] para controlar el botón "Calificar" en la lista.
  Future<void> _loadPendingRatings() async {
    final pending = <String>{};
    for (final r in _history) {
      if (r.status.toUpperCase() == 'COMPLETADO' &&
          r.estadoCancelacion != '1') {
        if (await DoctorRatingModal.isRatable(r)) {
          pending.add('${r.idtran}_${r.dr}');
        }
      }
    }
    if (mounted) setState(() => _pendingRatings = pending);
  }

  /// Carga los nombres completos de hospitales desde la API de regionales.
  Future<void> _fetchHospitalNames() async {
    try {
      final regionales = await _service.getRegionalesPorDepartamento(1);
      final map = <int, String>{};
      for (final regional in regionales) {
        for (final hospital in regional.hospitals) {
          final id = int.tryParse(hospital.id);
          if (id != null) map[id] = hospital.name;
        }
      }
      if (mounted) setState(() => _hospitalNames = map);
    } catch (_) {}
  }

  /// Retorna el nombre completo del hospital desde la API de regionales,
  /// fallback al nombre almacenado en la reserva.
  String _hospitalLabel(ReservaModel reserva) {
    if (reserva.idsuc != null) {
      final name = _hospitalNames[reserva.idsuc!];
      if (name != null && name.isNotEmpty) return name;
    }
    return reserva.hospital;
  }

  /// Descarga silenciosamente la foto del médico de la próxima cita para mostrarla en la tarjeta.
  Future<void> _fetchLatestDoctorPhoto(ReservaModel reserva) async {
    if (!reserva.canDownloadPdf) return;
    try {
      final detalle = await _service.getDetalleCitaMedica(
        gestion: reserva.gestion!,
        idins: reserva.idins!,
        idsuc: reserva.idsuc!,
        idtran: reserva.idtran!,
        dr: reserva.dr!,
      );
      final foto = detalle.fotoMedico;
      if (foto == null || foto.isEmpty) return;
      final clean = foto.contains(',') ? foto.split(',').last : foto;
      final bytes = base64Decode(clean.trim());
      if (mounted) setState(() => _latestDoctorPhotoBytes = bytes);
    } catch (_) {}
  }

  /// Foto en bytes del paciente actualmente seleccionado (beneficiario o titular).
  Uint8List? _patientPhotoBytes() {
    final b64 = _selectedBeneficiary != null
        ? _selectedBeneficiary!.photoBase64
        : UserSession.currentUser.photoBase64;
    if (b64.isEmpty) return null;
    try { return base64Decode(b64); } catch (_) { return null; }
  }

  /// Inicial del nombre del paciente para el avatar de respaldo.
  String _patientInitial() {
    final name = _selectedBeneficiary?.fullName.isNotEmpty == true
        ? _selectedBeneficiary!.fullName
        : UserSession.currentUser.fullName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Avatar circular del paciente (foto o inicial).
  Widget _buildPatientAvatar(double size, bool isDark) {
    final photoBytes = _patientPhotoBytes();
    final initial = _patientInitial();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
      ),
      child: ClipOval(
        child: photoBytes != null
            ? Image.memory(photoBytes, width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarInitialWidget(initial, size, isDark))
            : _avatarInitialWidget(initial, size, isDark),
      ),
    );
  }

  Widget _avatarInitialWidget(String initial, double size, bool isDark) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AppColors.accentForTheme(isDark),
        ),
      ),
    );
  }

  /// Avatar del médico para la tarjeta de próxima cita (usa foto descargada o inicial).
  Widget _buildLatestDoctorAvatar(String doctorName, bool isDark) {
    final initial = doctorName.isNotEmpty ? doctorName[0].toUpperCase() : '?';
    const accentColor = Color(0xFF2563EB);
    const size = 58.0;
    final textStyle = TextStyle(
      fontSize: size * 0.38,
      fontWeight: FontWeight.w700,
      color: accentColor,
      decoration: TextDecoration.none,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.1),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 2),
      ),
      child: ClipOval(
        child: _latestDoctorPhotoBytes != null
            ? Image.memory(_latestDoctorPhotoBytes!, width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: Text(initial, style: textStyle)))
            : Center(child: Text(initial, style: textStyle)),
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

  Widget _buildDetailRow({
    required bool isDark,
    required Color accentColor,
    required IconData icon,
    required String label,
    required String value,
    required AppResponsive r,
  }) {
    return Container(
      padding: EdgeInsets.all(r.spaceSm),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondaryC(isDark),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: context.texts.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryC(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final isTitularView = _selectedBeneficiary == null || _selectedBeneficiary!.isTitular;
    final label = isTitularView ? 'Titular' : _selectedBeneficiary!.relationship;
    final name = isTitularView
        ? UserSession.currentUser.displayName
        : _selectedBeneficiary!.displayTitle;

    // Foto del beneficiario seleccionado
    final b64 = isTitularView
        ? UserSession.currentUser.photoBase64
        : (_selectedBeneficiary?.photoBase64 ?? '');
    Uint8List? selectorPhoto;
    if (b64.isNotEmpty) {
      try { selectorPhoto = base64Decode(b64); } catch (_) {}
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    const avatarSize = 44.0;

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
                  if (name != label) ...[
                    SizedBox(height: 2),
                    Text(name, style: context.texts.bodySmall.copyWith(color: AppColors.textSecondaryC(isDark), fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            // Foto del beneficiario seleccionado
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: ClipOval(
                child: selectorPhoto != null
                    ? Image.memory(selectorPhoto, width: avatarSize, height: avatarSize, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(child: Text(initial,
                            style: TextStyle(fontSize: avatarSize * 0.42, fontWeight: FontWeight.w700, color: AppColors.primary))))
                    : Center(child: Text(initial,
                        style: TextStyle(fontSize: avatarSize * 0.42, fontWeight: FontWeight.w700, color: AppColors.primary))),
              ),
            ),
            SizedBox(width: context.r.spaceXs),
            Icon(CupertinoIcons.chevron_down, size: 18, color: AppColors.textTertiaryC(isDark)),
          ],
        ),
      ),
    );
  }


  Widget _sectionHeader(BuildContext context, String text) {
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
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondaryC(isDark),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark) {
    final r = context.r;
    final isTitularWithGroup = UserSession.currentUser.isTitular &&
        _beneficiaries.length > 1;

    // Nombre del beneficiario seleccionado (o del titular si no hay selección).
    final emptyLabel = _selectedBeneficiary != null && !_selectedBeneficiary!.isTitular
        ? '${_selectedBeneficiary!.displayTitle}\nno tiene atenciones registradas'
        : 'No tiene atenciones registradas';

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

              // Pull-to-refresh disponible incluso en estado vacío.
              CupertinoSliverRefreshControl(onRefresh: () async { _fetchReservas(); }),

              // Selector de beneficiario — el titular nunca queda atrapado
              // sin poder cambiar al ver que un miembro no tiene historial.
              if (isTitularWithGroup)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(r.paddingH, r.spaceSm, r.paddingH, 0),
                    child: _buildBeneficiarySelector(isDark),
                  ),
                ),

              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: FadeSlideIn(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.calendar,
                            size: 64,
                            color: AppColors.textTertiaryC(isDark)
                                .withValues(alpha: 0.3),
                          ),
                          SizedBox(height: r.spaceLg),
                          Text(
                            emptyLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryC(isDark),
                            ),
                          ),
                          SizedBox(height: r.spaceMd),
                          Text(
                            isTitularWithGroup
                                ? 'Puedes cambiar de miembro con el selector de arriba'
                                : 'El historial de atenciones aparecerá aquí',
                            textAlign: TextAlign.center,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

