import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/animations/optimized_animations.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
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
      final idper = int.tryParse(MockUserData.user.id) ?? 0;

      // Realizamos las peticiones. Si una falla, la otra puede seguir.
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

      if (mounted) {
        setState(() {
          _isLoading = false;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.name ?? '',
    ];

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          'Especialidad',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        backgroundColor: isDark 
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
            : AppColors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? const Center(key: ValueKey('loading'), child: CupertinoActivityIndicator(radius: 14))
              : _errorMessage != null
                  ? Center(
                      key: const ValueKey('error'),
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
                      key: const ValueKey('data'),
                      onRefresh: _fetchData,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        children: [
                          BreadcrumbChips(labels: breadcrumbs),
                          const SizedBox(height: 20),
                          const SectionHeader(text: 'CONSULTA DIRECTA'),
                          const SizedBox(height: 8),
                          if (_directas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                              child: Text('No hay especialidades directas disponibles.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            )
                          else
                            _buildSpecialtyList(
                              context,
                              _directas,
                              startDelay: 50,
                            ),
                          const SizedBox(height: 24),
                          const SectionHeader(text: 'INTERCONSULTA (HABILITADAS)'),
                          const SizedBox(height: 8),
                          if (_interconsultas.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                              child: Text('No tiene órdenes de interconsulta habilitadas.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            )
                          else
                            _buildSpecialtyList(
                              context,
                              _interconsultas,
                              showBadge: true,
                              startDelay: 100,
                            ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyList(
    BuildContext context,
    List<SpecialtyModel> specialties, {
    bool showBadge = false,
    int startDelay = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1)) : null,
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: AppColors.border.withValues(alpha: 0.5)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: showBadge
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForSpecialty(specialty.name),
                size: 30,
                color: showBadge ? AppColors.accent : (Theme.of(context).brightness == Brightness.dark ? AppColors.razer : AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specialty.name,
                    style: AppTypography.titleMedium.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (specialty.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      specialty.description,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Especialidad Médica',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showBadge && specialty.isAuthorized) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'AUTORIZADO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentDark,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForSpecialty(String name) {
    switch (name) {
      case 'Medicina General':
        return Icons.health_and_safety_outlined;
      case 'Medicina Familiar':
        return Icons.family_restroom_outlined;
      case 'Pediatría':
        return Icons.child_care_outlined;
      case 'Odontología':
        return Icons.sentiment_satisfied_outlined;
      case 'Ginecología':
        return Icons.pregnant_woman_outlined;
      case 'Cardiología':
        return Icons.monitor_heart_outlined;
      case 'Traumatología':
        return Icons.healing_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }
}
