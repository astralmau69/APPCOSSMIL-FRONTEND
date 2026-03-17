import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_specialty_data.dart';
import '../../../core/models/specialty_model.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
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

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Atrás',
        middle: const Text(
          'ESPECIALIDAD',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: CupertinoColors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            BreadcrumbChips(labels: breadcrumbs),
            const SizedBox(height: 20),
            // Consulta directa
            _sectionHeader('CONSULTA DIRECTA'),
            const SizedBox(height: 8),
            _buildSpecialtyList(
              context,
              MockSpecialtyData.directas,
            ),
            const SizedBox(height: 24),
            // Interconsulta
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.subtleGrey,
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
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < specialties.length; i++) ...[
            _specialtyTile(context, specialties[i], showBadge),
            if (i < specialties.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(height: 0.5, color: AppColors.cardBorder),
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        tabShell.bookingState.specialty = specialty;
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ScheduleScreen(tabShell: tabShell),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Ícono
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: showBadge
                    ? AppColors.authorizedGreen.withOpacity(0.08)
                    : AppColors.olive.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconForSpecialty(specialty.name),
                size: 18,
                color: showBadge ? AppColors.authorizedGreen : AppColors.olive,
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
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.subtleGrey,
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
                  color: AppColors.authorizedGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.authorizedGreen.withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'AUTORIZADO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.authorizedGreen,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.subtleGrey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForSpecialty(String name) {
    switch (name) {
      case 'Medicina Gen.':
        return CupertinoIcons.heart_fill;
      case 'Odontología':
        return CupertinoIcons.smiley_fill;
      case 'Ginecología':
        return CupertinoIcons.person_fill;
      case 'Cardiología':
        return CupertinoIcons.heart_circle_fill;
      case 'Traumatología':
        return CupertinoIcons.bandage_fill;
      default:
        return CupertinoIcons.plus_circle_fill;
    }
  }
}
