import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../models/beneficiary_model.dart';

class BeneficiaryDetailsModal extends StatelessWidget {
  final BeneficiaryModel beneficiary;

  const BeneficiaryDetailsModal({super.key, required this.beneficiary});

  static Future<void> show({
    required BuildContext context,
    required BeneficiaryModel beneficiary,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      pageBuilder: (context, _, __) {
        return BeneficiaryDetailsModal(beneficiary: beneficiary);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = context.r;
    final b = beneficiary;
    final isTitular = b.isTitular;
    final accentColor = isTitular
        ? AppColors.accentForTheme(isDark)
        : AppColors.primary;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: r.screenWidth * r.modalWidthFactor,
          constraints: BoxConstraints(maxWidth: r.modalMaxWidth),
          decoration: BoxDecoration(
            color: AppColors.cardBg(isDark),
            borderRadius: BorderRadius.circular(r.modalRadius),
            border: isTitular
                ? Border.all(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Gradient & Photo
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(r.modalRadius),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 30, // Centro la foto
                    child: _buildAvatar(b, accentColor, isDark),
                  ),
                ],
              ),

              const SizedBox(height: 70), // Espacio para la foto salida
              // Info principal
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.modalPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      b.displayTitle,
                      textAlign: TextAlign.center,
                      style: context.texts.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryC(isDark),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isTitular
                            ? accentColor.withValues(alpha: 0.1)
                            : AppColors.dividerC(isDark),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isTitular
                            ? 'Titular de la Cuenta'
                            : b.relationship.toUpperCase(),
                        style: TextStyle(
                          color: isTitular
                              ? accentColor
                              : AppColors.textSecondaryC(isDark),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Grid Info
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: CupertinoIcons.number,
                            label: 'Matrícula',
                            value: b.matricula.isNotEmpty
                                ? b.matricula
                                : 'No disp.',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoTile(
                            icon: CupertinoIcons.calendar,
                            label: 'Edad',
                            value: b.age != null ? '${b.age} años' : 'No disp.',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoTile(
                            icon: b.effectiveGender == 'FEMENINO'
                                ? Icons.female
                                : Icons.male,
                            label: 'Género',
                            value: b.displayGender.isNotEmpty
                                ? b.displayGender
                                : 'No disp.',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoTile(
                            icon: CupertinoIcons.person_badge_plus,
                            label: 'Grado',
                            value: isTitular
                                ? (b.displayGrado.isNotEmpty
                                      ? b.displayGrado
                                      : 'N/A')
                                : 'N/A',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Botón de Cierre
              Padding(
                padding: EdgeInsets.fromLTRB(
                  r.modalPadding,
                  0,
                  r.modalPadding,
                  r.modalPadding,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: BorderRadius.circular(r.buttonRadius),
                    color: AppColors.cardBorder(isDark),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cerrar Detalles',
                      style: context.texts.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryC(isDark),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BeneficiaryModel b, Color accent, bool isDark) {
    Widget imageContent;
    if (b.photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(b.photoBase64);
        imageContent = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initial(b),
        );
      } catch (_) {
        imageContent = _initial(b);
      }
    } else {
      imageContent = _initial(b);
    }

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.cardBg(isDark),
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(child: imageContent),
    );
  }

  Widget _initial(BeneficiaryModel b) {
    return Center(
      child: Text(
        b.initial,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 36,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textTertiaryC(isDark)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiaryC(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryC(isDark),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
