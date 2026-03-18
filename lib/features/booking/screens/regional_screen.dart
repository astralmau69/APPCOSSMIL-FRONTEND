import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_regional_data.dart';
import '../../../core/mock/mock_user_data.dart';
import '../../../core/models/regional_model.dart';
import '../../../core/models/hospital_model.dart';
import '../../../core/models/beneficiary_model.dart';
import '../../../core/widgets/beneficiary_selector_modal.dart';
import '../../../core/animations/animated_press_button.dart';
import '../../../core/animations/app_page_route.dart';
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
  int _expandedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Default to titular if no beneficiary selected
    final bs = widget.tabShell.bookingState;
    if (bs.beneficiary == null) {
      final titular = MockUserData.user.beneficiaries
          .firstWhere((b) => b.isTitular, orElse: () => MockUserData.user.beneficiaries[0]);
      bs.beneficiary = titular;
      bs.beneficiaryLabel = titular.isTitular ? 'Para mí' : titular.fullName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bs = widget.tabShell.bookingState;
    final currentBeneficiary = bs.beneficiary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ESTABLECIMIENTO',
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
            // ── Active profile selector ─────────────────────────────────
            _buildActiveProfileCard(currentBeneficiary),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '¿Qué establecimiento desea consultar?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < _regionals.length; i++)
              _buildRegionalItem(_regionals[i], i),
          ],
        ),
      ),
    );
  }

  // ── Profile selector card ────────────────────────────────────────────────

  Widget _buildActiveProfileCard(BeneficiaryModel? beneficiary) {
    if (beneficiary == null) return const SizedBox.shrink();

    final isTitular = beneficiary.isTitular;
    final avatarColor = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Yo (Titular)' : beneficiary.relationship;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  avatarColor,
                  avatarColor.withValues(alpha: 0.7),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              beneficiary.initial,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
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
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  beneficiary.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isTitular
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isTitular
                          ? AppColors.primary
                          : AppColors.accentDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Change button
          AnimatedPressButton(
            onTap: _onChangeBeneficiary,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz,
                      size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Cambiar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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

  Future<void> _onChangeBeneficiary() async {
    final selected = await BeneficiarySelectorModal.show(
      context: context,
      beneficiaries: MockUserData.user.beneficiaries,
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

  Widget _buildRegionalItem(RegionalModel regional, int index) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      regional.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
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
    return AnimatedPressButton(
      onTap: () {
        widget.tabShell.bookingState.regional = regional;
        widget.tabShell.bookingState.hospital = hospital;
        Navigator.push(
          context,
          AppPageRoute(
            builder: (_) => SpecialtyScreen(tabShell: widget.tabShell),
          ),
        );
      },
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          color: AppColors.primary.withValues(alpha: 0.05),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.apartment,
                  size: 12,
                  color: AppColors.primary,
                ),
              ),
            ),
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
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hospital.address,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
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
