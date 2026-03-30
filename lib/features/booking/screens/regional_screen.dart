import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/regional_model.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/models/horario_atencion_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/beneficiary_selector_modal.dart';
import '../../../core/animations/animated_press_button.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/services/location_service.dart';
import '../../../core/helpers/distance_helper.dart';
import '../../../core/widgets/cossmil_ios_alert.dart';
import 'specialty_screen.dart';

class RegionalScreen extends StatefulWidget {
  final TabShellState tabShell;

  const RegionalScreen({super.key, required this.tabShell});

  @override
  State<RegionalScreen> createState() => _RegionalScreenState();
}

class _RegionalScreenState extends State<RegionalScreen> {
  final _service = ProgramacionService();
  List<RegionalModel> _regionals = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _expandedIndex = -1;
  bool _locationApplied = false;

  @override
  void initState() {
    super.initState();
    // Default to titular if no beneficiary selected
    final bs = widget.tabShell.bookingState;
    if (bs.beneficiary == null) {
      final bens = UserSession.currentUser.beneficiaries;
      if (bens.isNotEmpty) {
        final titular = bens.firstWhere(
          (b) => b.isTitular,
          orElse: () => bens.first,
        );
        bs.beneficiary = titular;
        bs.beneficiaryLabel = titular.isTitular ? 'Para mí' : titular.fullName;
      }
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _service.getRegionalesPorDepartamento(1);
      
      bool locationUsed = false;
      try {
        final locationService = LocationService();
        // Pedir permisos si es que no los tiene (útil si el usuario se saltó el login por token guardado)
        final position = await locationService.getCurrentLocation(requestIfNotGranted: true);
        
        if (position != null) {
          locationUsed = true;
          for (var regional in data) {
            double minDistance = double.infinity;
            for (var hospital in regional.hospitals) {
              if (hospital.latitude != null && hospital.longitude != null) {
                final d = DistanceHelper.calculateDistanceInKm(
                  position.latitude, position.longitude,
                  hospital.latitude!, hospital.longitude!
                );
                if (d < minDistance) minDistance = d;
              }
            }
            if (minDistance != double.infinity) {
              regional.distanceFromUser = minDistance;
            }
          }
          
          // Ordenar departamentos por cercanía
          data.sort((a, b) {
            final dA = a.distanceFromUser ?? double.infinity;
            final dB = b.distanceFromUser ?? double.infinity;
            return dA.compareTo(dB);
          });
          
          // Expandir por defecto el más cercano si tenemos datos
          if (data.isNotEmpty && data.first.distanceFromUser != null) {
            _expandedIndex = 0;
          }
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
      }

      if (mounted) {
        setState(() {
          _regionals = data;
          _isLoading = false;
          _locationApplied = locationUsed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final currentBeneficiary = bs.beneficiary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Establecimiento',
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
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_errorMessage',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        CupertinoButton(
                            onPressed: _fetchData, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        // ── Active profile selector ─────────────────────────────────
                        FadeSlideIn(
                          offsetY: 30,
                          child: _buildActiveProfileCard(context, currentBeneficiary, isDark),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '¿Qué establecimiento desea consultar?',
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.textPrimaryC(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_locationApplied && _regionals.isNotEmpty && _regionals.first.distanceFromUser != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, top: 0, bottom: 12),
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: AppColors.accentForTheme(isDark)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Te mostramos primero el departamento más cercano a tu ubicación.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.accentForTheme(isDark),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (int i = 0; i < _regionals.length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 60 * (i + 1).clamp(0, 5)),
                            offsetY: 15,
                            child: _buildRegionalItem(context, _regionals[i], i, isDark),
                          ),
                        if (_regionals.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                                child: Text('No hay establecimientos disponibles.')),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── Profile selector card ────────────────────────────────────────────────

  Widget _buildActiveProfileCard(BuildContext context, BeneficiaryModel? beneficiary, bool isDark) {
    if (beneficiary == null) return const SizedBox.shrink();

    final isTitular = beneficiary.isTitular;
    final avatarColor = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Titular' : beneficiary.relationship;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
          color: isDark ? AppColors.cardBorder(isDark) : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
            ),
            child: ClipOval(
              child: (isTitular && UserSession.currentUser.photoBase64.isNotEmpty)
                  ? Image.memory(
                      base64Decode(UserSession.currentUser.photoBase64),
                      fit: BoxFit.cover,
                    )
                  : Center(
                      child: Text(
                        beneficiary.initial,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 28,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reserva para:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  beneficiary.fullName,
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTitular
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isTitular
                          ? AppColors.accentForTheme(isDark)
                          : AppColors.accentDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Change button
          AnimatedPressButton(
            onTap: _onChangeBeneficiary,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentForTheme(isDark).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: AppColors.accentForTheme(isDark).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz,
                      size: 14, color: AppColors.accentForTheme(isDark)),
                  const SizedBox(width: 4),
                  Text(
                    'Cambiar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentForTheme(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onChangeBeneficiary() async {
    final selected = await BeneficiarySelectorModal.show(
      context: context,
      beneficiaries: UserSession.currentUser.beneficiaries,
      currentId: widget.tabShell.bookingState.beneficiary?.id,
    );
    if (selected != null && mounted) {
      setState(() {
        widget.tabShell.bookingState.beneficiary = selected;
        widget.tabShell.bookingState.beneficiaryLabel =
            selected.isTitular ? 'Para mí' : selected.fullName;
      });
    }
  }

  // ── Regional list ────────────────────────────────────────────────────────

  Widget _buildRegionalItem(BuildContext context, RegionalModel regional, int index, bool isDark) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: isDark ? [] : AppColors.softShadow,
        border: isDark ? Border.all(color: AppColors.cardBorder(isDark)) : null,
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.accentForTheme(isDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            regional.name,
                            style: AppTypography.titleMedium.copyWith(
                               color: AppColors.textPrimaryC(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (index == 0 && _locationApplied && regional.distanceFromUser != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '📍 Más cercano',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentForTheme(isDark),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Simple conditional instead of AnimatedCrossFade — avoids rendering
          // both children simultaneously (double layout cost).
          if (isExpanded) _buildHospitalCards(context, regional, isDark),
        ],
      ),
    );
  }

  Widget _buildHospitalCards(BuildContext context, RegionalModel regional, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          for (int i = 0; i < regional.hospitals.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _hospitalCard(context, regional, regional.hospitals[i], isDark),
          ],
        ],
      ),
    );
  }

  bool _isVerifying = false;

  Future<void> _onHospitalSelected(RegionalModel regional, HospitalModel hospital) async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      final idsuc = int.tryParse(hospital.id) ?? 0;
      debugPrint('🏥 Hospital seleccionado: ${hospital.name} (hospital.id="${hospital.id}", idsuc=$idsuc)');

      // ── PASO 1: Consultar horarios disponibles ──────────────────────────
      List<HorarioAtencionModel> todosHorarios = [];
      List<HorarioAtencionModel> horariosApp = [];
      try {
        debugPrint('🌐 Llamando horarios-atencion con idins=1, idsuc=$idsuc');
        todosHorarios = await _service.getHorariosAtencion(1, idsuc);
        debugPrint('📋 Horarios recibidos: ${todosHorarios.length}');
        for (final h in todosHorarios) {
          debugPrint('   → idhorario=${h.idhorario}, desc="${h.descripcion}"');
        }

        horariosApp = todosHorarios
            .where((h) => h.descripcion.toUpperCase().contains('APP-MOVIL'))
            .toList();
        debugPrint('📱 Horarios APP-MOVIL filtrados: ${horariosApp.length}');
      } catch (e) {
        debugPrint('⚠️ Error al cargar horarios: $e (continuamos con verificar)');
      }

      if (!mounted) return;

      // ── PASO 2: Si hay horarios APP-MOVIL, mostrarlos al usuario ───────
      if (horariosApp.isNotEmpty) {
        setState(() => _isVerifying = false);
        final confirmo = await _showHorariosConfirmModal(horariosApp);
        if (confirmo != true || !mounted) return;
        setState(() => _isVerifying = true);
      }

      // ── PASO 3: Verificar horario de atención actual ────────────────────
      debugPrint('🌐 Llamando verificar-horario con idins=1, idsuc=$idsuc');
      final codigoHorario = await _service.verificarHorarioAtencion(1, idsuc);
      if (!mounted) return;

      debugPrint('🔍 verificar-horario devolvió: $codigoHorario');

      // ── PASO 4: Si verificar retorna un idhorario válido → continuar ───
      if (codigoHorario != null && codigoHorario > 0) {
        debugPrint('✅ Horario válido ($codigoHorario) → navegando a especialidades');
        widget.tabShell.bookingState.regional = regional;
        widget.tabShell.bookingState.hospital = hospital;
        widget.tabShell.bookingState.idhorario = codigoHorario;
        if (!mounted) return;
        Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => SpecialtyScreen(tabShell: widget.tabShell),
          ),
        );
      } else {
        // Sin horario válido → mostrar fuera de horario
        debugPrint('❌ verificar-horario no devolvió código válido → fuera de horario');
        setState(() => _isVerifying = false);
        final horariosParaMostrar = horariosApp.isNotEmpty ? horariosApp : todosHorarios;
        await _showFueraDeHorarioModal(horariosParaMostrar);
      }
    } catch (e) {
      if (!mounted) return;
      await CossmilIosAlert.show(
        context: context,
        title: 'Error de verificación',
        message: 'No se pudo verificar el horario de atención. Verifique su conexión e intente nuevamente.',
        type: AlertType.error,
        confirmText: 'Entendido',
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Modal interactivo: muestra horarios + botón "Continuar" ─────────────

  Future<bool?> _showHorariosConfirmModal(List<HorarioAtencionModel> horarios) async {
    if (!mounted) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.clock_fill, size: 18,
                color: AppColors.accentForTheme(isDark)),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Horarios de Atención',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        message: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Los horarios habilitados para reservas\nen la App Móvil son:',
              style: TextStyle(fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final h in horarios)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        h.rangoHorario,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.successLight : AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        h.descripcion,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Continuar',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.accentForTheme(isDark),
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ── Modal informativo: fuera de horario ─────────────────────────────────

  Future<void> _showFueraDeHorarioModal(List<HorarioAtencionModel> horarios) async {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.clock_fill, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Fuera de horario de atención',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        message: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Las reservas por la App Móvil solo están disponibles en los siguientes horarios. '
              'Por favor, intenta nuevamente dentro del horario habilitado.',
              style: TextStyle(fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (horarios.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final h in horarios)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.info.withValues(alpha: 0.15)
                          : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          h.rangoHorario,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          h.descripcion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'No se pudieron obtener los horarios habilitados en este momento. '
                'Por favor, intenta nuevamente más tarde.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryC(isDark)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(
            'Entendido',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _hospitalCard(BuildContext context, RegionalModel regional, HospitalModel hospital, bool isDark) {
    return AnimatedPressButton(
      onTap: () => _onHospitalSelected(regional, hospital),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.05),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment,
                size: 28,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hospital.name,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hospital.address,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.white : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
