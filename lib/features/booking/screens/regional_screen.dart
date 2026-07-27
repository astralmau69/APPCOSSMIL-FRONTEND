import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/animations/app_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/regional_model.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/data/app_session_cache.dart';
import '../../../core/widgets/beneficiary_selector_modal.dart';
import '../../../core/animations/animated_press_button.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/services/location_service.dart';
import '../../../core/helpers/distance_helper.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/hospital_card.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/loader_with_message.dart';
import '../../../core/widgets/inasistencias_modal.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/app_logger.dart';
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

/// Item plano para la grilla unificada Regional+Hospital.
class _HospitalEntry {
  final RegionalModel regional;
  final HospitalModel hospital;
  double? distanceKm;

  _HospitalEntry(this.regional, this.hospital);
}

class _RegionalScreenState extends State<RegionalScreen> {
  final _service = ProgramacionService();
  List<_HospitalEntry> _entries = [];
  List<BeneficiaryModel> _beneficiaries = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _locationApplied = false;
  bool _isCheckingCita = false;

  /// Estado de expansión por departamento (true = abierto).
  /// Por defecto el primer departamento (con el hospital más cercano o el
  /// primero en orden) queda expandido y los demás colapsados.
  final Map<String, bool> _expandedDeptos = {};

  @override
  void initState() {
    super.initState();
    _beneficiaries = List<BeneficiaryModel>.from(
      UserSession.currentUser.beneficiaries,
    );
    // Default to titular if no beneficiary selected
    final bs = widget.tabShell.bookingState;
    if (bs.beneficiary == null) {
      if (_beneficiaries.isNotEmpty) {
        final titular = _beneficiaries.firstWhere(
          (b) => b.isTitular,
          orElse: () => _beneficiaries.first,
        );
        bs.beneficiary = titular;
        bs.beneficiaryLabel = titular.isTitular
            ? 'Para mí'
            : titular.displayTitle;
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
      // 0.2: Consumir caché de sesión si está disponible — evita un HTTP redundante.
      // El caché se rellena en LoadingDataScreen con InitialDataOrchestrator.
      // Solo llama al backend si el caché está vacío (cold start).
      List<RegionalModel> rawData;
      if (AppSessionCache.isLoaded && AppSessionCache.regionales.isNotEmpty) {
        AppLogger.info(
          'RegionalScreen',
          'Usando regionales desde AppSessionCache (${AppSessionCache.regionales.length} elementos)',
        );
        rawData = List<RegionalModel>.from(AppSessionCache.regionales);
      } else {
        AppLogger.info(
          'RegionalScreen',
          'Caché vacío — cargando regionales desde API',
        );
        rawData = await _service.getRegionalesPorDepartamento(1);
      }

      // Sin filtro local: el backend ya devuelve únicamente las regionales/
      // hospitales habilitados. Mostramos todo lo que retorna el servicio.
      final entries = <_HospitalEntry>[];
      for (final regional in rawData) {
        for (final h in regional.hospitals) {
          entries.add(_HospitalEntry(regional, h));
        }
      }

      // Orden estable por idsuc (1 → 2 → 3) cuando no hay GPS.
      entries.sort((a, b) {
        final ia = int.tryParse(a.hospital.id) ?? 99;
        final ib = int.tryParse(b.hospital.id) ?? 99;
        return ia.compareTo(ib);
      });

      // Mostrar la lista de inmediato. La ubicación (GPS) se resuelve aparte
      // para no bloquear el primer render: pedir permiso y obtener el fix puede
      // tardar varios segundos, y eso retrasaba la aparición de los hospitales.
      if (mounted) {
        final freshBens = UserSession.currentUser.beneficiaries;
        final bs = widget.tabShell.bookingState;
        setState(() {
          _entries = entries;
          _isLoading = false;
          _beneficiaries = List<BeneficiaryModel>.from(freshBens);
          // Re-set default beneficiary if it was empty at initState time
          if (bs.beneficiary == null && freshBens.isNotEmpty) {
            final titular = freshBens.firstWhere(
              (b) => b.isTitular,
              orElse: () => freshBens.first,
            );
            bs.beneficiary = titular;
            bs.beneficiaryLabel = titular.isTitular
                ? 'Para mí'
                : titular.displayTitle;
          }
        });
      }

      // Reordenar por cercanía en segundo plano (sin bloquear la UI).
      unawaited(_applyLocationSorting());
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMapper.message(
            e,
            context: ErrorContext.cargarRegionales,
          );
          _isLoading = false;
        });
      }
    }
  }

  /// Obtiene la ubicación del dispositivo y reordena los establecimientos por
  /// cercanía. Corre en segundo plano (después de mostrar la lista) para no
  /// retrasar el primer render esperando el permiso/fix del GPS.
  Future<void> _applyLocationSorting() async {
    try {
      final locationService = LocationService();
      // No volver a pedir permiso aquí: la ubicación se solicita una sola vez en
      // el onboarding (primer arranque). Aquí solo se usa si ya está concedida.
      final position = await locationService.getCurrentLocation(
        requestIfNotGranted: false,
      );
      if (position == null || !mounted || _entries.isEmpty) return;

      for (final e in _entries) {
        final h = e.hospital;
        if (h.latitude != null && h.longitude != null) {
          e.distanceKm = DistanceHelper.calculateDistanceInKm(
            position.latitude,
            position.longitude,
            h.latitude!,
            h.longitude!,
          );
        }
      }
      final sorted = List<_HospitalEntry>.from(_entries)
        ..sort((a, b) {
          final dA = a.distanceKm ?? double.infinity;
          final dB = b.distanceKm ?? double.infinity;
          return dA.compareTo(dB);
        });

      if (mounted) {
        setState(() {
          _entries = sorted;
          _locationApplied = true;
        });
      }
    } catch (e) {
      AppLogger.warn(
        'RegionalScreen',
        'Error obteniendo ubicación del dispositivo',
        e,
      );
    }
  }

  /// Indica si el titular tiene al menos un beneficiario distinto de sí mismo.
  /// Usa la fuente más fresca disponible (UserSession y caché local) para que
  /// el botón "Cambiar" no parpadee mientras `_fetchData` aún no corre.
  bool _hasOtherBeneficiaries() {
    final fromSession = UserSession.currentUser.beneficiaries;
    final list = fromSession.isNotEmpty ? fromSession : _beneficiaries;
    if (list.length <= 1) return false;
    return list.any((b) => !b.isTitular);
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
      return AppStateWidget.error(
        title: 'No se pudo cargar los establecimientos',
        message: _errorMessage,
        onRetry: _fetchData,
      );
    }
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _fetchData),
        SliverPadding(
          padding: EdgeInsets.only(top: r.spaceMd, bottom: r.navBarBottomSpace),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FadeSlideIn(
                offsetY: 30,
                child: _buildActiveProfileCard(
                  context,
                  currentBeneficiary,
                  isDark,
                ),
              ),
              if (!UserSession.currentUser.isTitular) ...[
                SizedBox(height: r.spaceMd),
                FadeSlideIn(
                  offsetY: 20,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.spaceMd,
                        vertical: r.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.info.withValues(alpha: 0.12)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(r.radiusMd),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              CupertinoIcons.info_circle_fill,
                              size: r.iconSm,
                              color: AppColors.info,
                            ),
                          ),
                          SizedBox(width: r.spaceSm),
                          Expanded(
                            child: Text(
                              'Como beneficiario solo puedes reservar citas para ti mismo. '
                              'Si necesitas reservar para otro familiar, debe hacerlo el titular del seguro.',
                              style: context.texts.bodySmall.copyWith(
                                color: AppColors.textSecondaryC(isDark),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: r.spaceXl),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                child: Text(
                  'Seleccione el establecimiento de su preferencia',
                  style: context.texts.headlineMedium.copyWith(
                    color: AppColors.textPrimaryC(isDark),
                  ),
                ),
              ),
              SizedBox(height: r.spaceSm),
              if (_locationApplied &&
                  _entries.isNotEmpty &&
                  _entries.first.distanceKm != null)
                Padding(
                  padding: EdgeInsets.only(
                    left: r.paddingH,
                    right: r.paddingH,
                    top: 0,
                    bottom: r.spaceMd,
                  ),
                  child: Wrap(
                    spacing: r.spaceSm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.location_solid,
                        size: r.iconSm,
                        color: AppColors.accentForTheme(isDark),
                      ),
                      Text(
                        'Ordenado por cercanía a tu ubicación',
                        style: context.texts.bodySmall.copyWith(
                          color: AppColors.accentForTheme(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ..._buildSectionedHospitalList(context, isDark, r),
              if (_entries.isEmpty)
                Padding(
                  padding: EdgeInsets.all(r.spaceXxl),
                  child: const Center(
                    child: Text('No hay establecimientos disponibles.'),
                  ),
                ),
            ]),
          ),
        ),
      ],
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
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: r.navTitleSize,
            color: AppColors.textPrimaryC(isDark),
          ),
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
        child: Column(children: [Expanded(child: _buildBody(context))]),
      ),
    );
  }

  // ── Profile selector card ────────────────────────────────────────────────

  Widget _buildActiveProfileCard(
    BuildContext context,
    BeneficiaryModel? beneficiary,
    bool isDark,
  ) {
    if (beneficiary == null) return const SizedBox.shrink();

    final r = context.r;
    final isTitular = beneficiary.isTitular;
    final avatarColor = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Titular' : beneficiary.relationship;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.paddingH),
      child: LiquidGlass(
        isDark: isDark,
        borderRadius: BorderRadius.circular(r.cardRadius),
        padding: EdgeInsets.all(r.cardPadding),
        shadow: AppColors.cardShadowFor(isDark),
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
                      // Solo mostrar "Cambiar" si el titular tiene grupo familiar
                      // con al menos un beneficiario distinto del titular. Si la
                      // API no devolvió familia (cuenta sola o cuenta beneficiario),
                      // ocultar la opción para no abrir un selector vacío.
                      if (UserSession.currentUser.isTitular &&
                          _hasOtherBeneficiaries())
                        AnimatedPressButton(
                          onTap: _onChangeBeneficiary,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.chipPaddingH,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentForTheme(
                                isDark,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(r.chipRadius),
                              border: Border.all(
                                color: AppColors.accentForTheme(
                                  isDark,
                                ).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_2_squarepath,
                                  size: r.iconSm * 0.7,
                                  color: AppColors.accentForTheme(isDark),
                                ),
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
                  // Chip de etiqueta:
                  //   - Beneficiario: siempre muestra el parentesco (Esposa, Hijo…)
                  //   - Titular: solo si tiene grupo familiar. Sin familia el chip
                  //     "Titular" es redundante (no hay con quién distinguirse).
                  if (!isTitular || _hasOtherBeneficiaries()) ...[
                    SizedBox(height: r.spaceSm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.chipPaddingH,
                        vertical: r.chipPaddingV,
                      ),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent(BeneficiaryModel beneficiary, bool isTitular) {
    // Reactivo: la foto puede llegar en SEGUNDO PLANO después de entrar a
    // Reservar. Escuchamos a UserSession para refrescar el avatar sin reiniciar.
    return ValueListenableBuilder<UserModel>(
      valueListenable: UserSession.userNotifier,
      builder: (context, user, _) {
        final r = context.r;
        // Titular: preferir foto de UserSession.
        // Beneficiario: re-resolver la versión más reciente desde la sesión
        // (las fotos de familiares también llegan en segundo plano), con
        // fallback al objeto recibido.
        String photoB64;
        if (isTitular) {
          photoB64 = user.photoBase64.isNotEmpty
              ? user.photoBase64
              : beneficiary.photoBase64;
        } else {
          final fresh = user.beneficiaries.where(
            (b) => b.id == beneficiary.id && b.photoBase64.isNotEmpty,
          );
          photoB64 = fresh.isNotEmpty
              ? fresh.first.photoBase64
              : beneficiary.photoBase64;
        }

        if (photoB64.isNotEmpty) {
          try {
            return Image.memory(
              base64Decode(photoB64),
              fit: BoxFit.cover,
              width: r.avatarLg,
              height: r.avatarLg,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _avatarInitial(beneficiary),
            );
          } catch (_) {
            // Bad base64 — fall through to initial
          }
        }
        return _avatarInitial(beneficiary);
      },
    );
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
      showAppDialog<void>(
        context: context,
        barrierDismissible: false,
        silent: true, // esperar no es un evento: un loader no suena
        builder: (_) =>
            const LoaderWithMessage(message: 'Cargando familiares…'),
      );
      loaderOpen = true;
      try {
        final idper = int.tryParse(UserSession.currentUser.id) ?? 0;
        final fresh = await _service.getGrupoFamiliar(idper);
        if (!mounted) return;
        if (loaderOpen) {
          loaderOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (fresh.isNotEmpty) {
          bens = fresh;
          UserSession.currentUser = UserSession.currentUser.copyWith(
            beneficiaries: fresh,
          );
          setState(() => _beneficiaries = List.from(fresh));
        }
      } catch (_) {
        if (mounted && loaderOpen) {
          loaderOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
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
        widget.tabShell.bookingState.beneficiaryLabel = selected.isTitular
            ? 'Para mí'
            : selected.displayTitle;
      });
    }
  }

  Future<void> _showValidacionModal(String message) async {
    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return CupertinoAlertDialog(
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_shield_fill,
                color: CupertinoColors.systemOrange,
                size: 20,
              ),
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

  // ── Hospital list (flat) ────────────────────────────────────────────────

  Future<void> _onHospitalSelected(
    RegionalModel regional,
    HospitalModel hospital,
  ) async {
    debugPrint(
      '🏥 Hospital seleccionado: ${hospital.name} (hospital.id="${hospital.id}")',
    );
    widget.tabShell.bookingState.regional = regional;
    widget.tabShell.bookingState.hospital = hospital;

    // Modo tutorial: nunca se ejecutan verificaciones reales de negocio
    // (podrían bloquear la demo por inasistencias/aportes reales del
    // usuario) — se avanza directo al siguiente paso.
    final isTutorial = widget.tabShell.bookingState.isTutorialMode;

    // Para titulares: verificar validaciones + cita activa del beneficiario elegido.
    if (UserSession.currentUser.isTitular && !isTutorial) {
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

        showAppDialog<void>(
          context: context,
          barrierDismissible: false,
          silent: true, // esperar no es un evento: un loader no suena
          builder: (_) =>
              const LoaderWithMessage(message: 'Verificando disponibilidad…'),
        );
        loaderOpen = true;

        // 1a. Penalización por inasistencias (3 faltas) del familiar elegido.
        //     Se consulta con el idper de la persona que va a ser atendida; si
        //     está penalizada (data:true) debe reservar de forma presencial.
        final inasistenciasMsg = await _service.validarInasistencias(idper);
        if (!mounted) return;
        if (inasistenciasMsg != null) {
          closeLoader();
          await showInasistenciasModal(context, inasistenciasMsg);
          return; // no continuar
        }

        // 1b. Validaciones de aportes (Art. 186).
        final validMsg = await _service.verificarValidaciones(matricula, idper);
        if (!mounted) return;
        closeLoader();

        if (validMsg != null) {
          await _showValidacionModal(validMsg);
          return; // no continuar
        }

        // 2. [Cita activa] — verificación movida al paso "Elige tu Fecha" (DatePickerScreen).
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

  /// Construye la lista de hospitales agrupada en desplegables por departamento.
  ///
  /// Cada `RegionalModel.name` representa un departamento (La Paz, Cochabamba,
  /// Santa Cruz, etc.). El primer departamento queda expandido por defecto
  /// (es el del hospital más cercano si hay GPS) y los demás colapsados.
  List<Widget> _buildSectionedHospitalList(
    BuildContext context,
    bool isDark,
    AppResponsive r,
  ) {
    if (_entries.isEmpty) return const [];

    // Agrupar respetando el orden de aparición en _entries.
    final byDepto = <String, List<_HospitalEntry>>{};
    for (final e in _entries) {
      final depto = e.regional.name.trim().isEmpty ? 'Otros' : e.regional.name;
      byDepto.putIfAbsent(depto, () => []).add(e);
    }

    final widgets = <Widget>[];
    int globalIndex = 0;
    bool firstDepto = true;

    for (final entry in byDepto.entries) {
      final depto = entry.key;
      final hospitals = entry.value;

      // Inicializar el primer depto como expandido si nunca fue tocado.
      if (firstDepto && !_expandedDeptos.containsKey(depto)) {
        _expandedDeptos[depto] = true;
      }
      firstDepto = false;

      final isExpanded = _expandedDeptos[depto] ?? false;

      // Capturar el globalIndex de inicio del depto para el badge "Más cercano".
      final deptoStartIndex = globalIndex;

      // El depto que contiene el hospital más cercano es el primero (entries
      // viene ordenado por distancia). Su header muestra "Más cercano a ti".
      final isNearestDepto =
          _locationApplied &&
          deptoStartIndex == 0 &&
          hospitals.isNotEmpty &&
          hospitals.first.distanceKm != null;

      widgets.add(
        _buildDeptoHeader(
          depto: depto,
          count: hospitals.length,
          isExpanded: isExpanded,
          isNearest: isNearestDepto,
          isDark: isDark,
          r: r,
          onTap: () {
            setState(() {
              _expandedDeptos[depto] = !isExpanded;
            });
          },
        ),
      );

      widgets.add(
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: ClipRect(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isExpanded ? 1.0 : 0.0,
              child: !isExpanded
                  ? const SizedBox(width: double.infinity, height: 0)
                  : Column(
                      children: [
                        for (int i = 0; i < hospitals.length; i++)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              r.paddingH,
                              0,
                              r.paddingH,
                              r.listItemSpacing,
                            ),
                            child:
                                (widget.tabShell.bookingState.isTutorialMode &&
                                    deptoStartIndex == 0 &&
                                    i == 0)
                                ? GuidedTapHint(
                                    child: _hospitalCard(
                                      context,
                                      hospitals[i],
                                      isDark: isDark,
                                    ),
                                  )
                                : _hospitalCard(
                                    context,
                                    hospitals[i],
                                    isDark: isDark,
                                  ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      );

      globalIndex += hospitals.length;
    }
    return widgets;
  }

  /// Header desplegable del departamento. Toca para expandir/colapsar.
  Widget _buildDeptoHeader({
    required String depto,
    required int count,
    required bool isExpanded,
    required bool isNearest,
    required bool isDark,
    required AppResponsive r,
    required VoidCallback onTap,
  }) {
    final accent = AppColors.accentForTheme(isDark);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.paddingH,
        r.spaceMd,
        r.paddingH,
        r.spaceSm,
      ),
      child: AnimatedPressButton(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: r.spaceMd,
            vertical: r.spaceSm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(r.radiusMd),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: r.sectionBarWidth + 1,
                height: r.iconSm,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: r.spaceSm),
              // Nombre del departamento — tipografía responsiva.
              Flexible(
                child: Text(
                  depto.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: accent,
                  ),
                ),
              ),
              // Badge "Más cercano a ti" en la barra de la regional.
              if (isNearest) ...[
                SizedBox(width: r.spaceSm),
                Flexible(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.chipPaddingH,
                      vertical: r.chipPaddingV,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.location_fill,
                          size: r.iconSm * 0.7,
                          color: accent,
                        ),
                        SizedBox(width: r.spaceXs),
                        Flexible(
                          child: Text(
                            'Más cercano a ti',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.labelSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(width: r.spaceSm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.chipPaddingH,
                  vertical: 2,
                ),
                margin: EdgeInsets.only(right: r.spaceSm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(r.radiusSm),
                ),
                child: Text(
                  '$count',
                  style: context.texts.labelSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  CupertinoIcons.chevron_down,
                  size: r.iconSm,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hospitalCard(
    BuildContext context,
    _HospitalEntry entry, {
    required bool isDark,
  }) {
    return HospitalCard(
      hospital: entry.hospital,
      regionalName: entry.regional.name,
      isDark: isDark,
      onTap: () => _onHospitalSelected(entry.regional, entry.hospital),
    );
  }
}
