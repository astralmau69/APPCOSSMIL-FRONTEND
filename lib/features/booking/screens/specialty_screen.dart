import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_specialty_data.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../core/animations/app_page_route.dart';
import '../../../shell/tab_shell.dart';
import 'schedule_screen.dart';

class SpecialtyScreen extends StatelessWidget {
  final TabShellState tabShell;

  const SpecialtyScreen({super.key, required this.tabShell});

  @override
  Widget build(BuildContext context) {
    final bs = tabShell.bookingState;
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
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            BreadcrumbChips(labels: breadcrumbs),
            const SizedBox(height: 20),
            _sectionHeader('CONSULTA DIRECTA'),
            const SizedBox(height: 8),
            _buildSpecialtyList(
              context,
              MockSpecialtyData.directas,
            ),
            const SizedBox(height: 24),
            _sectionHeader('INTERCONSULTA (HABILITADAS)'),
            const SizedBox(height: 8),
            _buildSpecialtyList(
              context,
              MockSpecialtyData.interconsultas,
              showBadge: true,
            ),
          ],
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
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
        tabShell.bookingState.specialty = specialty;
        Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => ScheduleScreen(tabShell: tabShell),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: showBadge
                    ? AppColors.accent.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForSpecialty(specialty.name),
                size: 18,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
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
