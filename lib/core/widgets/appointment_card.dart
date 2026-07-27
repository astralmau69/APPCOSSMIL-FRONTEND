import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../extensions/responsive_extensions.dart';
import '../animations/optimized_animations.dart';
import '../models/reserva_model.dart';
import '../animations/animated_status_badge.dart';

/// Card reutilizable para mostrar una reserva/cita médica.
/// Adaptada al formato real del backend historial-citas:
/// especialidad, médico, regional, fechaCita, codadm, estado.
class AppointmentCard extends StatelessWidget {
  final ReservaModel appointment;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(appointment.status);
    final r = context.r;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spaceSm),
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.98,
        child: RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(r.cardPadding),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? (isDark ? const Color(0xFF0C2D1E) : const Color(0xFFF0FDF4))
                  : AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(r.cardRadius),
              border: Border.all(
                color: isHighlighted
                    ? AppColors.success
                    : config.isHighlighted
                    ? config.color.withValues(alpha: 0.3)
                    : AppColors.cardBorder(isDark),
                width: isHighlighted ? 1.5 : 0.5,
              ),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(
                          alpha: isDark ? 0.25 : 0.20,
                        ),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : AppColors.cardShadowFor(isDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isHighlighted) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: r.chipPaddingH,
                      vertical: r.chipPaddingV + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF065F46)
                          : AppColors.success,
                      borderRadius: BorderRadius.circular(r.radiusSm),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: r.spaceXs),
                        Text(
                          'NUEVA RESERVA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: r.sectionLabelSize,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.spaceSm),
                ],
                // Row 1: Avatar + Especialidad + Status
                Row(
                  children: [
                    _buildAvatar(context, config, r),
                    SizedBox(width: r.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.specialty,
                            style: context.texts.titleLarge.copyWith(
                              color: AppColors.textPrimaryC(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: context.r.spaceXs),
                          Text(
                            appointment.doctorName,
                            style: context.texts.bodySmall.copyWith(
                              color: AppColors.accentForTheme(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (appointment.patientName.isNotEmpty) ...[
                            SizedBox(height: context.r.spaceXs),
                            Text(
                              'Paciente: ${appointment.patientName}',
                              style: context.texts.bodySmall.copyWith(
                                color: AppColors.textSecondaryC(isDark),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: r.spaceXs),
                    Flexible(
                      flex: 0,
                      child: AnimatedStatusBadge.fromStatus(appointment.status),
                    ),
                  ],
                ),
                SizedBox(height: r.spaceSm),
                Container(height: 0.5, color: AppColors.divider),
                SizedBox(height: r.spaceSm),
                // Row 2: Detalles (fecha, regional, código)
                Wrap(
                  spacing: r.spaceXs,
                  runSpacing: r.spaceXs,
                  children: [
                    _detailChip(
                      context,
                      Icons.calendar_today,
                      appointment.formattedDate,
                      isDark: isDark,
                      isHighlight: isDark,
                    ),
                    if (appointment.time.isNotEmpty)
                      _detailChip(
                        context,
                        Icons.schedule,
                        appointment.time,
                        isDark: isDark,
                      ),
                    if (appointment.consultorio != null &&
                        appointment.consultorio!.isNotEmpty)
                      _detailChip(
                        context,
                        Icons.meeting_room_outlined,
                        appointment.consultorio!,
                        isDark: isDark,
                      ),
                  ],
                ),
                if (appointment.hospital.isNotEmpty) ...[
                  SizedBox(height: r.spaceXs),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: r.chipPaddingH,
                      vertical: r.chipPaddingV + 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(r.radiusSm),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          size: 14,
                          color: AppColors.textTertiaryC(isDark),
                        ),
                        SizedBox(width: r.spaceXs),
                        Flexible(
                          child: Text(
                            appointment.hospital,
                            style: context.texts.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryC(isDark),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    _StatusConfig config,
    AppResponsive r,
  ) {
    final size = r.listAvatarSize;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: config.color),
      alignment: Alignment.center,
      child: Icon(config.icon, color: AppColors.white, size: r.iconMd),
    );
  }

  Widget _detailChip(
    BuildContext context,
    IconData icon,
    String text, {
    required bool isDark,
    bool isHighlight = false,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isHighlight
              ? AppColors.primaryMedium
              : AppColors.textTertiaryC(isDark),
        ),
        SizedBox(width: context.r.spaceXs),
        Flexible(
          child: Text(
            text,
            style: context.texts.bodySmall.copyWith(
              color: isHighlight ? AppColors.primaryMedium : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  _StatusConfig _statusConfig(String status) {
    switch (status) {
      case 'Completado':
        return _StatusConfig(
          color: AppColors.accent,
          icon: Icons.task_alt,
          isHighlighted: false,
        );
      case 'Falta':
        return _StatusConfig(
          color: const Color(0xFF9333EA),
          icon: Icons.person_off,
          isHighlighted: true,
        );
      case 'Pendiente':
        return const _StatusConfig(
          color: Color(0xFF2563EB),
          icon: Icons.schedule,
          isHighlighted: true,
        );
      case 'Cancelado':
        return _StatusConfig(
          color: AppColors.textSecondary,
          icon: Icons.cancel_outlined,
          isHighlighted: false,
        );
      default:
        return _StatusConfig(
          color: AppColors.textSecondary,
          icon: Icons.info,
          isHighlighted: false,
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final bool isHighlighted;

  const _StatusConfig({
    required this.color,
    required this.icon,
    required this.isHighlighted,
  });
}
