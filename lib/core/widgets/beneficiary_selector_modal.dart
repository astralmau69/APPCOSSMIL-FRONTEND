import 'dart:convert';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
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
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: r.maxContentWidth,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: context.r.spaceMd),
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(context.r.spaceXs),
                ),
              ),
              SizedBox(height: r.spaceLg),
              // Title
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                child: Row(
                  children: [
                    Icon(Icons.people_alt, size: r.iconSm, color: AppColors.primary),
                    SizedBox(width: r.spaceSm),
                    Expanded(
                      child: Text(
                        '¿Para quién es la reserva?',
                        style: TextStyle(
                          fontSize: r.isSmallPhone ? 15 : 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryC(isDark),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spaceXs),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.paddingH),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Selecciona el miembro de tu grupo familiar',
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryC(isDark),
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.spaceMd),
              Container(height: 0.5, color: AppColors.border),
              // List
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: context.r.spaceSm),
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
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final isTitular = beneficiary.isTitular;
    final avatarColor = isTitular ? AppColors.primary : AppColors.accent;
    final label = isTitular ? 'Yo (Titular)' : beneficiary.relationship;
    final avatarSize = r.avatarMd;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.paddingH, vertical: r.cardPadding),
        color: isSelected
            ? (isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.primaryLight)
            : Colors.transparent,
        child: Row(
          children: [
            // Avatar
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor,
              ),
              child: ClipOval(
                child: beneficiary.photoBase64.isNotEmpty
                    ? Image.memory(
                        base64Decode(beneficiary.photoBase64),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackAvatar(beneficiary, avatarSize),
                      )
                    : _fallbackAvatar(beneficiary, avatarSize),
              ),
            ),
            SizedBox(width: r.spaceMd),
            // Name + relationship
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beneficiary.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: r.isSmallPhone ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryC(isDark),
                    ),
                  ),
                  SizedBox(height: context.r.spaceXs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isTitular
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(context.r.badgeRadius),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: r.isSmallPhone ? 12 : 14,
                        fontWeight: FontWeight.w700,
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

  Widget _fallbackAvatar(BeneficiaryModel beneficiary, double size) {
    return Center(
      child: Text(
        beneficiary.initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
