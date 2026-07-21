import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/helpers/specialty_filter.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/specialty_tile.dart';
import '../../../core/widgets/guided_tap_hint.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/utils/error_mapper.dart';
import 'schedule_screen.dart';

class SpecialtyScreen extends StatefulWidget {
  final TabShellState tabShell;
  final VoidCallback? onNext;

  const SpecialtyScreen({super.key, required this.tabShell, this.onNext});

  @override
  State<SpecialtyScreen> createState() => _SpecialtyScreenState();
}

class _SpecialtyScreenState extends State<SpecialtyScreen> {
  final _service = ProgramacionService();
  List<SpecialtyModel> _directas = [];
  List<SpecialtyModel> _interconsultas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bs = widget.tabShell.bookingState;
      final idsuc = int.tryParse(bs.hospital?.id ?? '') ?? 0;
      // Usar el idper del BENEFICIARIO seleccionado (no siempre el titular).
      // Si se está reservando para un familiar, las interconsultas deben
      // ser las de ese familiar, no las del titular.
      final beneficiary = bs.beneficiary;
      final idper = int.tryParse(
            (!UserSession.currentUser.isTitular || beneficiary == null || beneficiary.isTitular)
                ? UserSession.currentUser.id
                : beneficiary.id,
          ) ?? 0;

      final directasFuture = _service.getEspecialidadesDirectas(1, idsuc);
      final interFuture = _service.getEspecialidadesInterconsulta(idper);

      try {
        _directas = await directasFuture;
      } catch (e) {
        debugPrint('Error cargando directas: $e');
        _directas = [];
      }

      try {
        _interconsultas = await interFuture;
      } catch (e) {
        debugPrint('Error cargando interconsultas: $e');
        _interconsultas = [];
      }

      // ── Filtrar por edad y género de la persona que reserva ─────────
      final int personAge = UserSession.ageFor(beneficiary);
      final String personGender = UserSession.genderFor(beneficiary);

      debugPrint('🔎 SpecialtyFilter: beneficiary=${beneficiary?.fullName ?? "titular"}, '
          'age=$personAge, gender="$personGender", '
          'directas=${_directas.length}, inter=${_interconsultas.length}');

      _directas = SpecialtyFilter.apply(
        specialties: _directas,
        age: personAge,
        gender: personGender,
      );

      _interconsultas = SpecialtyFilter.apply(
        specialties: _interconsultas,
        age: personAge,
        gender: personGender,
      );

      // ── Eliminar duplicados por nombre (REPORTE 006) ──────────────
      _directas = _deduplicateByName(_directas);
      _interconsultas = _deduplicateByName(_interconsultas);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMapper.message(e, context: ErrorContext.cargarEspecialidades);
          _isLoading = false;
        });
      }
    }
  }

  /// Elimina especialidades duplicadas por nombre (case-insensitive).
  List<SpecialtyModel> _deduplicateByName(List<SpecialtyModel> list) {
    final seen = <String>{};
    return list.where((s) => seen.add(s.name.toLowerCase())).toList();
  }

  Widget _buildBody(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? ListView(
              key: const ValueKey('skeleton'),
              padding: EdgeInsets.only(top: context.r.spaceLg, bottom: context.r.navBarBottomSpace),
              children: [
                SizedBox(height: context.r.spaceMd),
                const SkeletonSpecialtyList(count: 6),
              ],
            )
          : _errorMessage != null
              ? AppStateWidget.error(
                  key: const ValueKey('error'),
                  title: _errorMessage!.contains('sesión') || _errorMessage!.contains('Sesión')
                      ? 'Sesión expirada'
                      : 'No se pudieron cargar las especialidades',
                  message: _errorMessage!,
                  onRetry: _errorMessage!.contains('sesión') || _errorMessage!.contains('Sesión')
                      ? () => Navigator.of(context, rootNavigator: true)
                            .pushReplacementNamed('/login')
                      : _fetchData,
                  retryLabel: _errorMessage!.contains('sesión') || _errorMessage!.contains('Sesión')
                      ? 'Ir al login'
                      : 'Reintentar',
                  icon: _errorMessage!.contains('sesión') || _errorMessage!.contains('Sesión')
                      ? CupertinoIcons.lock_shield
                      : CupertinoIcons.wifi_slash,
                )
              : (_directas.isEmpty && _interconsultas.isEmpty)
                  ? AppStateWidget.empty(
                      key: const ValueKey('empty'),
                      title: 'Sin especialidades disponibles',
                      message: _emptySpecialtiesMessage(),
                      icon: CupertinoIcons.heart_slash,
                    )
                  : RefreshIndicator(
                      key: const ValueKey('data'),
                      onRefresh: _fetchData,
                      child: ListView(
                        padding: EdgeInsets.only(top: context.r.spaceLg, bottom: context.r.navBarBottomSpace),
                        children: [
                          BreadcrumbChips(labels: breadcrumbs),
                          SizedBox(height: context.r.spaceLg),
                          if (_directas.isNotEmpty) ...[
                            const SectionHeader(text: 'CONSULTA DIRECTA'),
                            SizedBox(height: context.r.spaceMd),
                            _buildSpecialtyList(
                              context,
                              _directas,
                              startDelay: 50,
                              highlightFirst: bs.isTutorialMode,
                            ),
                            SizedBox(height: context.r.spaceXl),
                          ],
                          if (_interconsultas.isNotEmpty) ...[
                            const SectionHeader(text: 'INTERCONSULTA (HABILITADAS)'),
                            SizedBox(height: context.r.spaceSm),
                            _buildInterconsultaInfo(context),
                            SizedBox(height: context.r.spaceMd),
                            _buildSpecialtyList(
                              context,
                              _interconsultas,
                              showBadge: true,
                              startDelay: 100,
                            ),
                          ],
                          if (_directas.isNotEmpty && _interconsultas.isEmpty)
                            SizedBox(height: context.r.spaceSm),
                        ],
                      ),
                    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Modo embebido: solo el contenido.
    if (widget.onNext != null) {
      return _buildBody(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffoldBg(isDark),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Especialidad',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimaryC(isDark),
          ),
        ),
        backgroundColor:
            (isDark ? AppColors.darkSurface : AppColors.white).withValues(alpha: 0.92),
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

  Widget _buildInterconsultaInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: context.r.spaceMd, vertical: context.r.spaceSm),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.accent.withValues(alpha: 0.10)
              : AppColors.accentLight,
          borderRadius: BorderRadius.circular(context.r.radiusMd),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(CupertinoIcons.doc_checkmark_fill,
                  size: context.r.iconSm, color: AppColors.accent),
            ),
            SizedBox(width: context.r.spaceSm),
            Expanded(
              child: Text(
                'Las especialidades de interconsulta requieren autorización previa: '
                'fueron derivadas por tu médico de cabecera y ya están habilitadas para reserva.',
                style: context.texts.bodySmall.copyWith(
                  color: AppColors.textSecondaryC(isDark),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptySpecialtiesMessage() {
    final bs = widget.tabShell.bookingState;
    final beneficiary = bs.beneficiary;
    final name = (beneficiary != null && !beneficiary.isTitular)
        ? beneficiary.displayTitle.split(' ').first
        : null;
    if (name != null) {
      return 'No hay especialidades habilitadas para $name en este establecimiento. '
          'Puedes probar con otro establecimiento o contactar a mesa de partes.';
    }
    return 'No hay especialidades habilitadas para tu perfil en este establecimiento. '
        'Puedes probar con otro establecimiento o contactar a mesa de partes.';
  }

  Widget _buildSpecialtyList(
    BuildContext context,
    List<SpecialtyModel> specialties, {
    bool showBadge = false,
    int startDelay = 0,
    bool highlightFirst = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      child: LiquidGlass(
        isDark: isDark,
        borderRadius: BorderRadius.circular(context.r.radiusXl),
        shadow: isDark ? null : AppColors.softShadow,
        child: Column(
        children: [
          for (int i = 0; i < specialties.length; i++) ...[
            if (i < 5)
              FadeSlideIn(
                delay: Duration(milliseconds: startDelay + (i * 40)),
                offsetY: 10,
                child: (highlightFirst && i == 0)
                    ? GuidedTapHint(child: _specialtyTile(context, specialties[i], showBadge))
                    : _specialtyTile(context, specialties[i], showBadge),
              )
            else
              _specialtyTile(context, specialties[i], showBadge),
            if (i < specialties.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.r.cardPadding),
                child: Container(
                  height: 0.5,
                  color: AppColors.dividerC(isDark),
                ),
              ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _specialtyTile(
    BuildContext context,
    SpecialtyModel specialty,
    bool showBadge,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SpecialtyTile(
      specialty: specialty,
      showBadge: showBadge,
      isDark: isDark,
      onTap: () {
        widget.tabShell.bookingState.specialty = specialty;
        if (widget.onNext != null) {
          widget.onNext!();
        } else {
          Navigator.push(
            context,
            AppPageRoute(
              builder: (_) => ScheduleScreen(tabShell: widget.tabShell),
            ),
          );
        }
      },
    );
  }
}
