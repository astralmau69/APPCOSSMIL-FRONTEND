import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../models/specialty_model.dart';

/// Fila de selección de especialidad médica (ícono temático + nombre +
/// descripción + badge "AUTORIZADO" para interconsultas). Extraída de
/// `SpecialtyScreen._specialtyTile` para reutilizarla también en el
/// tutorial guiado — mismo componente en ambos lugares.
class SpecialtyTile extends StatelessWidget {
  final SpecialtyModel specialty;
  final bool showBadge;
  final bool isDark;
  final VoidCallback onTap;

  const SpecialtyTile({
    super.key,
    required this.specialty,
    required this.isDark,
    required this.onTap,
    this.showBadge = false,
  });

  static IconData iconFor(String name) {
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

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.cardPadding,
          vertical: r.cardPadding,
        ),
        child: Row(
          children: [
            Container(
              width: r.listAvatarSize,
              height: r.listAvatarSize,
              decoration: BoxDecoration(
                color: showBadge
                    ? AppColors.accent.withValues(alpha: 0.10)
                    : AppColors.accentForTheme(isDark).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(r.radiusMd),
              ),
              child: Icon(
                iconFor(specialty.name),
                size: r.iconMd,
                color: showBadge
                    ? AppColors.accent
                    : AppColors.accentForTheme(isDark),
              ),
            ),
            SizedBox(width: r.spaceMd),
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
                  SizedBox(height: r.spaceXs),
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
                padding: EdgeInsets.symmetric(
                  horizontal: r.chipPaddingH,
                  vertical: r.chipPaddingV,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : AppColors.accentLight,
                  borderRadius: BorderRadius.circular(r.radiusSm),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'AUTORIZADO',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.accentLight
                        : AppColors.accentDark,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(width: r.spaceSm),
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
}
