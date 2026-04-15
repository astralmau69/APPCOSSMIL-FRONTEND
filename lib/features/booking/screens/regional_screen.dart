import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
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
import '../../../core/utils/error_mapper.dart';
import 'specialty_screen.dart';

class RegionalScreen extends StatefulWidget {
  final TabShellState tabShell;

  /// Cuando no es null, la pantalla se muestra sin scaffold/stepper propio
  /// y llama este callback en vez de Navigator.push al avanzar.
  final VoidCallback? onNext;

  const RegionalScreen({super.key, required this.tabShell, this.onNext});

  @override
  State<RegionalScreen> createState() => _RegionalScreenState();
}

class _RegionalScreenState extends State<RegionalScreen> {
  final _service = ProgramacionService();
  List<RegionalModel> _regionals = [];
  List<BeneficiaryModel> _beneficiaries = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _expandedIndex = -1;
  bool _locationApplied = false;
  bool _isCheckingCita = false;

  @override
  void initState() {
    super.initState();
    _beneficiaries = List<BeneficiaryModel>.from(UserSession.currentUser.beneficiaries);
    // Default to titular if no beneficiary selected
    final bs = widget.tabShell.bookingState;
    if (bs.beneficiary == null) {
      if (_beneficiaries.isNotEmpty) {
        final titular = _beneficiaries.firstWhere(
          (b) => b.isTitular,
          orElse: () => _beneficiaries.first,
        );
        bs.beneficiary = titular;
        bs.beneficiaryLabel = titular.isTitular ? 'Para mí' : titular.displayTitle;
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
      final rawData = await _service.getRegionalesPorDepartamento(1);

      // Filtro: solo mostrar La Paz – Hospital Militar Central.
      final data = <RegionalModel>[];
      for (final regional in rawData) {
        if (!regional.name.toLowerCase().contains('paz')) continue;
        final hospitals = regional.hospitals
            .where((h) => h.name.toLowerCase().contains('central'))
            .toList();
        if (hospitals.isEmpty) continue;
        data.add(RegionalModel(
          id: regional.id,
          name: regional.name,
          hospitals: hospitals,
        ));
      }

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
        final freshBens = UserSession.currentUser.beneficiaries;
        final bs = widget.tabShell.bookingState;
        setState(() {
          _regionals = data;
          _isLoading = false;
          _locationApplied = locationUsed;
          _beneficiaries = List<BeneficiaryModel>.from(freshBens);
          // Re-set default beneficiary if it was empty at initState time
          if (bs.beneficiary == null && freshBens.isNotEmpty) {
            final titular = freshBens.firstWhere(
              (b) => b.isTitular,
              orElse: () => freshBens.first,
            );
            bs.beneficiary = titular;
            bs.beneficiaryLabel = titular.isTitular ? 'Para mí' : titular.displayTitle;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMapper.message(e, context: ErrorContext.cargarRegionales);
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildBody(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final currentBeneficiary = bs.beneficiary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    if (_isLoading) {
      return ListView(
        padding: EdgeInsets.only(top: r.spaceMd, bottom: r.navBarBottomSpace),
        children: const [SkeletonRegionalList(count: 4)],
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            SizedBox(height: r.spaceMd),
            CupertinoButton(onPressed: _fetchData, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: EdgeInsets.only(top: r.spaceMd, bottom: r.navBarBottomSpace),
        children: [
          FadeSlideIn(
            offsetY: 30,
            child: _buildActiveProfileCard(context, currentBeneficiary, isDark),
          ),
          SizedBox(height: r.spaceXl),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.paddingH),
            child: Text(
              'Seleccione la Agencia Regional de su preferencia',
              style: context.texts.headlineMedium.copyWith(
                color: AppColors.textPrimaryC(isDark),
              ),
            ),
          ),
          SizedBox(height: r.spaceSm),
          if (_locationApplied && _regionals.isNotEmpty && _regionals.first.distanceFromUser != null)
            Padding(
              padding: EdgeInsets.only(left: r.paddingH, right: r.paddingH, top: 0, bottom: r.spaceMd),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: r.iconSm, color: AppColors.accentForTheme(isDark)),
                  SizedBox(width: r.spaceSm),
                  Expanded(
                    child: Text(
                      'Te mostramos primero el departamento más cercano a tu ubicación.',
                      style: context.texts.bodySmall.copyWith(
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
            Padding(
              padding: EdgeInsets.all(r.spaceXxl),
              child: const Center(child: Text('No hay establecimientos disponibles.')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modo embebido: solo el contenido, sin scaffold ni stepper.
    if (widget.onNext != null) {
      return _buildBody(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Establecimiento',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: r.navTitleSize, color: AppColors.textPrimaryC(isDark)),
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
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  // ── Profile selector card ────────────────────────────────────────────────

  Widget _buildActiveProfileCard(BuildContext context, BeneficiaryModel? beneficiary, bool isDark) {
    if (beneficiary == null) return const SizedBox.shrink();

    final r = context.r;
    final isTitular = beneficiary.isTitular;
    final avatarColor = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Titular' : beneficiary.relationship;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.paddingH),
      padding: EdgeInsets.all(r.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(r.cardRadius),
        boxShadow: AppColors.cardShadowFor(isDark),
        border: Border.all(
          color: isDark ? AppColors.cardBorder(isDark) : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: r.avatarLg,
            height: r.avatarLg,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
            ),
            child: ClipOval(
              child: _buildAvatarContent(beneficiary, isTitular),
            ),
          ),
          SizedBox(width: r.spaceMd),
          // Name + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'Reserva para:',
                          style: context.texts.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (UserSession.currentUser.isTitular)
                        AnimatedPressButton(
                          onTap: _onChangeBeneficiary,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.chipPaddingH, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentForTheme(isDark).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(r.chipRadius),
                              border: Border.all(
                                color: AppColors.accentForTheme(isDark).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swap_horiz,
                                    size: r.iconSm * 0.7, color: AppColors.accentForTheme(isDark)),
                                SizedBox(width: r.spaceXs),
                                Text(
                                  'Cambiar',
                                  style: context.texts.bodySmall.copyWith(
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
                  SizedBox(height: r.spaceXs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      (beneficiary.isTitular && beneficiary.grado.isEmpty)
                          ? UserSession.currentUser.displayName
                          : beneficiary.displayTitle,
                      style: context.texts.headlineMedium.copyWith(
                        color: AppColors.textPrimaryC(isDark),
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(height: r.spaceSm),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.chipPaddingH, vertical: r.chipPaddingV),
                    decoration: BoxDecoration(
                      color: isTitular
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(r.radiusSm),
                    ),
                    child: Text(
                      label,
                      style: context.texts.bodySmall.copyWith(
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
          ],
        ),
    );
  }

  Widget _buildAvatarContent(BeneficiaryModel beneficiary, bool isTitular) {
    final r = context.r;
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
          width: r.avatarLg,
          height: r.avatarLg,
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
        style: context.texts.headlineLarge.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _onChangeBeneficiary() async {
    // 1. Preferir datos frescos de la sesión (cargados por _tryEnterBookingTab).
    var bens = UserSession.currentUser.beneficiaries.isNotEmpty
        ? UserSession.currentUser.beneficiaries
        : _beneficiaries;

    // 2. Si solo hay el titular (o vacío), ir al API para obtener la familia.
    //    Cubre la race condition donde _fetchData corrió antes que _tryEnterBookingTab,
    //    y también el caso donde el backend omitió la familia en el token de login.
    if (bens.length <= 1 && UserSession.currentUser.isTitular) {
      bool loaderOpen = false;
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14)),
      );
      loaderOpen = true;
      try {
        final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
        final fresh = await _service.getGrupoFamiliar(idper);
        if (!mounted) return;
        if (loaderOpen) { loaderOpen = false; Navigator.of(context, rootNavigator: true).pop(); }
        if (fresh.isNotEmpty) {
          bens = fresh;
          UserSession.currentUser = UserSession.currentUser.copyWith(beneficiaries: fresh);
          setState(() => _beneficiaries = List.from(fresh));
        }
      } catch (_) {
        if (mounted && loaderOpen) { loaderOpen = false; Navigator.of(context, rootNavigator: true).pop(); }
        bens = _beneficiaries; // fallback a caché local
      }
    }

    if (!mounted) return;

    final selected = await BeneficiarySelectorModal.show(
      context: context,
      beneficiaries: bens,
      currentId: widget.tabShell.bookingState.beneficiary?.id,
    );
    if (selected != null && mounted) {
      setState(() {
        _beneficiaries = List.from(bens); // sincronizar caché local
        widget.tabShell.bookingState.beneficiary = selected;
        widget.tabShell.bookingState.beneficiaryLabel =
            selected.isTitular ? 'Para mí' : selected.displayTitle;
      });
    }
  }

  Future<void> _showValidacionModal(String message) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return CupertinoAlertDialog(
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.exclamationmark_shield_fill,
                  color: CupertinoColors.systemOrange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Atención no disponible',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message,
              style: TextStyle(
                height: 1.4,
                color: isDark ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  // ── Regional list ────────────────────────────────────────────────────────

  Widget _buildRegionalItem(BuildContext context, RegionalModel regional, int index, bool isDark) {
    final isExpanded = _expandedIndex == index;
    final r = context.r;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: r.spaceXs),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(r.cardRadius),
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
              padding: EdgeInsets.symmetric(
                  horizontal: r.tileHorizontalPad, vertical: r.tileVerticalPad),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: r.iconMd,
                    color: AppColors.accentForTheme(isDark),
                  ),
                  SizedBox(width: r.spaceSm),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            regional.name,
                            style: context.texts.titleLarge.copyWith( // Mejor jerarquía visual
                               color: AppColors.textPrimaryC(isDark),
                               fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2, // Permits wrapping
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (index == 0 && _locationApplied && regional.distanceFromUser != null) ...[
                          SizedBox(width: r.spaceSm),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: r.chipPaddingH, vertical: r.chipPaddingV),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(r.radiusSm),
                            ),
                            child: Text(
                              'Más cercano',
                              style: context.texts.labelSmall.copyWith(
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
                    size: r.iconSm,
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
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.paddingH, 0, r.paddingH, r.paddingH),
      child: Column(
        children: [
          for (int i = 0; i < regional.hospitals.length; i++) ...[
            if (i > 0) SizedBox(height: r.listItemSpacing),
            _hospitalCard(context, regional, regional.hospitals[i], isDark),
          ],
        ],
      ),
    );
  }

  Future<void> _onHospitalSelected(RegionalModel regional, HospitalModel hospital) async {
    debugPrint('🏥 Hospital seleccionado: ${hospital.name} (hospital.id="${hospital.id}")');
    widget.tabShell.bookingState.regional = regional;
    widget.tabShell.bookingState.hospital = hospital;

    // Para titulares: verificar validaciones + cita activa del beneficiario elegido.
    if (UserSession.currentUser.isTitular) {
      if (_isCheckingCita) return;
      setState(() => _isCheckingCita = true);

      bool loaderOpen = false;
      void closeLoader() {
        if (loaderOpen && mounted) {
          loaderOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      try {
        // 1. Verificar aportes (Art. 186) para la persona que va a ser atendida.
        //    Se comprueba aquí (al elegir sucursal) porque el titular pudo cambiar
        //    el beneficiario con el botón "Cambiar" antes de llegar a este punto.
        final bs = widget.tabShell.bookingState;
        final beneficiary = bs.beneficiary;
        final matricula = (beneficiary == null || beneficiary.isTitular)
            ? UserSession.currentUser.matricula
            : (beneficiary.matricula.isNotEmpty
                ? beneficiary.matricula
                : UserSession.currentUser.matricula);
        final idper = (beneficiary == null || beneficiary.isTitular)
            ? (int.tryParse(UserSession.currentUser.id) ?? 0)
            : (int.tryParse(beneficiary.id) ?? 0);

        showCupertinoDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CupertinoActivityIndicator(radius: 14)),
        );
        loaderOpen = true;

        final validMsg = await _service.verificarValidaciones(matricula, idper);
        if (!mounted) return;
        closeLoader();

        if (validMsg != null) {
          await _showValidacionModal(validMsg);
          return; // no continuar
        }

        // 2. Verificar si tiene cita activa.
        final hasActiveCita = await widget.tabShell.checkAndShowActiveCitaForBeneficiary();
        if (hasActiveCita) return;
      } catch (e) {
        closeLoader();
        debugPrint('⚠️ Error en verificaciones del hospital: $e');
      } finally {
        if (mounted) setState(() => _isCheckingCita = false);
      }
    }

    // Sin cita activa → continuar al siguiente paso
    if (!mounted) return;
    if (widget.onNext != null) {
      widget.onNext!();
    } else {
      Navigator.push(
        context,
        AppPageRoute(
          builder: (_) => SpecialtyScreen(tabShell: widget.tabShell),
        ),
      );
    }
  }

  Widget _hospitalCard(BuildContext context, RegionalModel regional, HospitalModel hospital, bool isDark) {
    final r = context.r;
    return AnimatedPressButton(
      onTap: () => _onHospitalSelected(regional, hospital),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(r.spaceMd), // Standard spacing
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.radiusLg), // Better corner radius
          color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.05),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: r.listAvatarSize,
              height: r.listAvatarSize,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment,
                size: r.iconLg * 0.7,
                color: isDark ? AppColors.white : AppColors.primary,
              ),
            ),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hospital.name,
                    style: context.texts.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryC(isDark),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.spaceSm),
                  Text(
                    hospital.address,
                    style: context.texts.bodySmall,
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
