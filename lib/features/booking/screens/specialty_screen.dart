import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/services/programacion_service.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
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
    final breadcrumbs = [
      bs.beneficiaryLabel ?? 'Para mí',
      bs.regional?.name ?? '',
      bs.hospital?.shortName ?? '',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ESPECIALIDAD',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: AppColors.white,
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppColors.border, height: 0.5),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_errorMessage',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _fetchData, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchData,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        BreadcrumbChips(labels: breadcrumbs),
                        const SizedBox(height: 20),
                        _sectionHeader('CONSULTA DIRECTA'),
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
                          ),
                        const SizedBox(height: 24),
                        _sectionHeader('INTERCONSULTA (HABILITADAS)'),
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
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSpecialtyList(
    BuildContext context,
    List<SpecialtyModel> specialties, {
    bool showBadge = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (i * 100)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: _specialtyTile(context, specialties[i], showBadge),
            ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: showBadge
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _iconForSpecialty(specialty.name),
                size: 22,
                color: showBadge ? AppColors.accent : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specialty.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (specialty.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      specialty.description,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Especialidad Médica',
                      style: TextStyle(
                        fontSize: 16,
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
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                    letterSpacing: 0.5,
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
