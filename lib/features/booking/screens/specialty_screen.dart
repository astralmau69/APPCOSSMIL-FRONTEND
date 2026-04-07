import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/responsive_extensions.dart';
import '../../../core/session/user_session.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/helpers/specialty_filter.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../core/widgets/app_state_widget.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/booking_stepper.dart';
import '../../../shell/tab_shell.dart';
import '../../../core/utils/error_mapper.dart';
import 'schedule_screen.dart';

class SpecialtyScreen extends StatefulWidget {
  final TabShellState tabShell;

  const SpecialtyScreen({super.key, required this.tabShell});

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
      final idper = int.tryParse(UserSession.currentUser.id) ?? 0;

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
      final beneficiary = bs.beneficiary;
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

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
    ];

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
            const BookingStepper(currentStep: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isLoading
                    ? ListView(
                        key: const ValueKey('skeleton'),
                        padding: EdgeInsets.symmetric(vertical: context.r.spaceLg),
                        children: const [
                          SizedBox(height: 16),
                          SkeletonSpecialtyList(count: 6),
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
                            padding: EdgeInsets.symmetric(vertical: context.r.spaceLg),
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
                                ),
                                SizedBox(height: context.r.spaceXl),
                              ],
                              if (_interconsultas.isNotEmpty) ...[
                                const SectionHeader(text: 'INTERCONSULTA (HABILITADAS)'),
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
        ? beneficiary.fullName.split(' ').first
        : null;
    if (name != null) {
      return 'No hay especialidades habilitadas para $name en este establecimiento. '
          'Puedes probar con otro establecimiento o contactar a mesa de partes.';
    }
    return 'No hay especialidades habilitadas para tu perfil en este establecimiento. '
        'Puedes probar con otro establecimiento o contactar a mesa de partes.';
  }

  bool _isAuthError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('unauthenticated');
  }

  Widget _buildSpecialtyList(
    BuildContext context,
    List<SpecialtyModel> specialties, {
    bool showBadge = false,
    int startDelay = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.r.paddingH),
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        borderRadius: BorderRadius.circular(context.r.radiusXl),
        border: Border.all(color: AppColors.cardBorder(isDark)),
        boxShadow: isDark ? [] : AppColors.softShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < specialties.length; i++) ...[
            if (i < 5)
              FadeSlideIn(
                delay: Duration(milliseconds: startDelay + (i * 40)),
                offsetY: 10,
                child: _specialtyTile(context, specialties[i], showBadge),
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
    );
  }

  Widget _specialtyTile(
    BuildContext context,
    SpecialtyModel specialty,
    bool showBadge,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.tabShell.bookingState.specialty = specialty;
        Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => ScheduleScreen(tabShell: widget.tabShell),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.r.cardPadding, vertical: context.r.cardPadding),
        child: Row(
          children: [
            Container(
              width: context.r.listAvatarSize,
              height: context.r.listAvatarSize,
              decoration: BoxDecoration(
                color: showBadge
                    ? AppColors.accent.withValues(alpha: 0.10)
                    : AppColors.accentForTheme(isDark).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(context.r.radiusMd),
              ),
              child: Icon(
                _iconForSpecialty(specialty.name),
                size: 26,
                color: showBadge
                    ? AppColors.accent
                    : AppColors.accentForTheme(isDark),
              ),
            ),
            SizedBox(width: context.r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specialty.name,
                    style: context.texts.titleMedium.copyWith(
                      color: AppColors.textPrimaryC(isDark),
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    specialty.description.isNotEmpty
                        ? specialty.description
                        : 'Especialidad Médica',
                    style: context.texts.bodySmall.copyWith(
                      color: AppColors.textSecondaryC(isDark),
                      fontStyle: specialty.description.isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showBadge && specialty.isAuthorized) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: context.r.chipPaddingH, vertical: context.r.chipPaddingV),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.accentLight,
                  borderRadius: BorderRadius.circular(context.r.radiusSm),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'AUTORIZADO',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.accentLight : AppColors.accentDark,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(width: context.r.spaceSm),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.textTertiaryC(isDark),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForSpecialty(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('general')) return Icons.health_and_safety_outlined;
    if (lower.contains('familiar')) return Icons.family_restroom_outlined;
    if (lower.contains('pediatr')) return Icons.child_care_outlined;
    if (lower.contains('odonto')) return Icons.sentiment_satisfied_outlined;
    if (lower.contains('ginecol')) return Icons.pregnant_woman_outlined;
    if (lower.contains('cardio')) return Icons.monitor_heart_outlined;
    if (lower.contains('trauma')) return Icons.healing_outlined;
    if (lower.contains('oftalmo')) return Icons.visibility_outlined;
    if (lower.contains('dermat')) return Icons.spa_outlined;
    if (lower.contains('neurolog')) return Icons.psychology_outlined;
    if (lower.contains('urolog')) return Icons.water_drop_outlined;
    if (lower.contains('otorrino')) return Icons.hearing_outlined;
    if (lower.contains('cirug')) return Icons.local_hospital_outlined;
    if (lower.contains('intern')) return Icons.biotech_outlined;
    return Icons.medical_services_outlined;
  }
}
