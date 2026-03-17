import 'package:flutter/cupertino.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_regional_data.dart';
import '../../../core/models/regional_model.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/widgets/breadcrumb_chips.dart';
import '../../../shell/tab_shell.dart';
import 'specialty_screen.dart';

class RegionalScreen extends StatefulWidget {
  final TabShellState tabShell;

  const RegionalScreen({super.key, required this.tabShell});

  @override
  State<RegionalScreen> createState() => _RegionalScreenState();
}

class _RegionalScreenState extends State<RegionalScreen> {
  final _regionals = MockRegionalData.regionals;
  int _expandedIndex = 0; // La Paz abierta por defecto

  @override
  Widget build(BuildContext context) {
    final beneficiaryLabel =
        widget.tabShell.bookingState.beneficiaryLabel ?? 'Para mí';

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgGrey,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: 'Atrás',
        middle: const Text(
          'REGIONALES',
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
            // Chip beneficiario
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.olive.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.olive.withOpacity(0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.person_fill,
                          size: 12, color: AppColors.olive),
                      const SizedBox(width: 4),
                      Text(
                        beneficiaryLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.olive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                'SELECCIONE REGIONAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.subtleGrey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Lista de regionales
            for (int i = 0; i < _regionals.length; i++)
              _buildRegionalItem(_regionals[i], i),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionalItem(RegionalModel regional, int index) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.location_solid,
                    size: 18,
                    color: AppColors.olive,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      regional.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: AppColors.subtleGrey,
                  ),
                ],
              ),
            ),
          ),
          // Hospitals (expanded)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildHospitalCards(regional),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildHospitalCards(RegionalModel regional) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          for (int i = 0; i < regional.hospitals.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _hospitalCard(regional, regional.hospitals[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hospitalCard(RegionalModel regional, HospitalModel hospital) {
    return GestureDetector(
      onTap: () {
        widget.tabShell.bookingState.regional = regional;
        widget.tabShell.bookingState.hospital = hospital;
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => SpecialtyScreen(tabShell: widget.tabShell),
          ),
        );
      },
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.olive.withOpacity(0.06),
          border: Border.all(color: AppColors.olive.withOpacity(0.12)),
        ),
        child: Stack(
          children: [
            // Ícono decorativo
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.olive.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.building_2_fill,
                  size: 12,
                  color: AppColors.olive,
                ),
              ),
            ),
            // Info
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hospital.shortName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hospital.address,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.subtleGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
