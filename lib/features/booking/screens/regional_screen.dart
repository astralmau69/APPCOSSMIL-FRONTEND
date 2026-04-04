import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/regional_model.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/beneficiary_selector_modal.dart';
import '../../../core/animations/animated_press_button.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/services/location_service.dart';
import '../../../core/helpers/distance_helper.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/booking_stepper.dart';
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
        child: Column(
          children: [
            const BookingStepper(currentStep: 0),
            Expanded(
              child: _isLoading
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: const [SkeletonRegionalList(count: 4)],
                    )
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
          ],
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
      margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      padding: EdgeInsets.all(context.r.cardPadding),
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
              child: _buildAvatarContent(beneficiary, isTitular),
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
          if (UserSession.currentUser.isTitular && UserSession.currentUser.beneficiaries.length > 1)
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

  Widget _buildAvatarContent(BeneficiaryModel beneficiary, bool isTitular) {
    // Titular: prefer UserSession photo, fallback to beneficiary photo
    final photoB64 = isTitular
        ? (UserSession.currentUser.photoBase64.isNotEmpty
            ? UserSession.currentUser.photoBase64
            : beneficiary.photoBase64)
        : beneficiary.photoBase64;

    if (photoB64.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(photoB64),
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (_, __, ___) => _avatarInitial(beneficiary),
        );
      } catch (_) {
        // Bad base64 — fall through to initial
      }
    }
    return _avatarInitial(beneficiary);
  }

  Widget _avatarInitial(BeneficiaryModel beneficiary) {
    return Center(
      child: Text(
        beneficiary.initial,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 28,
        ),
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
        border: Border.all(color: AppColors.cardBorder(isDark), width: 0.5),
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
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              regional.name,
                              style: AppTypography.titleMedium.copyWith(
                                 color: AppColors.textPrimaryC(isDark),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
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
                              'Más cercano',
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
          if (isExpanded) _buildHospitalCards(context, regional, isDark),
        ],
      ),
    );
  }

  Widget _buildHospitalCards(BuildContext context, RegionalModel regional, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(context.r.paddingH, 0, context.r.paddingH, context.r.paddingH),
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

  void _onHospitalSelected(RegionalModel regional, HospitalModel hospital) {
    debugPrint('🏥 Hospital seleccionado: ${hospital.name} (hospital.id="${hospital.id}")');
    widget.tabShell.bookingState.regional = regional;
    widget.tabShell.bookingState.hospital = hospital;
    Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => SpecialtyScreen(tabShell: widget.tabShell),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hospital.name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
