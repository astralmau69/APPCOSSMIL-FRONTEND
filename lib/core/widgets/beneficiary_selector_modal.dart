import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/beneficiary_model.dart';

/// Modal reutilizable para seleccionar un miembro del grupo familiar.
/// Diseñado para ser reutilizado en cualquier flujo (booking, perfil, etc.).
///
/// Uso:
/// ```dart
/// final selected = await BeneficiarySelectorModal.show(
///   context: context,
///   beneficiaries: user.beneficiaries,
///   currentId: selectedBeneficiary.id,
/// );
/// ```
class BeneficiarySelectorModal {
  static Future<BeneficiaryModel?> show({
    required BuildContext context,
    required List<BeneficiaryModel> beneficiaries,
    String? currentId,
  }) {
    return showModalBottomSheet<BeneficiaryModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ModalContent(
        beneficiaries: beneficiaries,
        currentId: currentId,
      ),
    );
  }
}

class _ModalContent extends StatelessWidget {
  final List<BeneficiaryModel> beneficiaries;
  final String? currentId;

  const _ModalContent({
    required this.beneficiaries,
    this.currentId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.people_alt, size: 20, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  '¿Para quién es la reserva?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Selecciona el miembro de tu grupo familiar',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 0.5, color: AppColors.border),
          // List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: beneficiaries.length,
              itemBuilder: (context, index) {
                final b = beneficiaries[index];
                final isSelected = b.id == currentId;
                return _BeneficiaryTile(
                  beneficiary: b,
                  isSelected: isSelected,
                  onTap: () => Navigator.pop(context, b),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _BeneficiaryTile extends StatelessWidget {
  final BeneficiaryModel beneficiary;
  final bool isSelected;
  final VoidCallback onTap;

  const _BeneficiaryTile({
    required this.beneficiary,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTitular = beneficiary.isTitular;
    final avatarColor = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Yo (Titular)' : beneficiary.relationship;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        color: isSelected
            ? AppColors.primaryLight
            : Colors.transparent,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
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
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + relationship
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beneficiary.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
            // Check icon
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
