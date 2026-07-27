import 'package:flutter/cupertino.dart';

import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';

/// Chip de horario disponible (verde, "Disponible"). Extraído de
/// `ScheduleScreen._timeChip` para reutilizarlo también en el tutorial
/// guiado — mismo componente en ambos lugares.
///
/// Solo existe la variante "disponible": la pantalla real ya filtra los
/// horarios ocupados antes de llegar a la grilla, así que este chip nunca
/// necesitó un estado "no disponible".
class TimeSlotChip extends StatelessWidget {
  final String timeLabel;
  final bool isDark;
  final VoidCallback onTap;

  const TimeSlotChip({
    super.key,
    required this.timeLabel,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final Color bgColor = isDark
        ? const Color(0xFF064E3B)
        : const Color(0xFF86EFAC);
    final Color textColor = isDark
        ? const Color(0xFF6EE7B7)
        : const Color(0xFF14532D);
    final Color borderColor = isDark
        ? const Color(0xFF059669)
        : const Color(0xFF16A34A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(r.radiusMd),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.30),
              blurRadius: 8,
              spreadRadius: isDark ? 0 : 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeLabel,
              style: context.texts.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: r.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF059669).withValues(alpha: 0.3)
                    : const Color(0xFF065F46).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.badgeRadius),
              ),
              child: Text(
                'Disponible',
                style: context.texts.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFF059669),
                  letterSpacing: 0.3,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
