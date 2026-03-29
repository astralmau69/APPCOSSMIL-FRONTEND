import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_constants.dart';
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

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(appointment.status);
    final responsive = ResponsiveData.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: responsive.isSmallPhone ? 8 : 12),
      child: OptimizedPressButton(
        onTap: onTap,
        scaleDown: 0.98,
        child: RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(responsive.isSmallPhone ? 12 : 14),
            decoration: BoxDecoration(
              color: AppColors.cardBg(isDark),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: config.isHighlighted
                    ? config.color.withValues(alpha: 0.3)
                    : AppColors.cardBorder(isDark),
                width: 0.5,
              ),
              boxShadow: isDark ? [] : AppShadows.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Avatar + Especialidad + Status
                Row(
                  children: [
                    _buildAvatar(config, responsive),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.specialty,
                            style: AppTypography.titleLarge.copyWith(
                              fontSize: responsive.isSmallPhone ? 15 : 16,
                              color: AppColors.textPrimaryC(isDark),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            appointment.doctorName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.accentForTheme(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedStatusBadge.fromStatus(appointment.status),
                  ],
                ),
                const SizedBox(height: 10),
                Container(height: 0.5, color: AppColors.divider),
                const SizedBox(height: 10),
                // Row 2: Detalles (fecha, regional, código)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _detailChip(Icons.calendar_today, appointment.formattedDate, isDark: isDark, isHighlight: isDark),
                    if (appointment.time.isNotEmpty)
                      _detailChip(Icons.schedule, appointment.time, isDark: isDark),
                    _detailChip(Icons.apartment, appointment.hospital, isDark: isDark),
                    if (appointment.consultorio != null && appointment.consultorio!.isNotEmpty)
                      _detailChip(Icons.meeting_room_outlined, appointment.consultorio!, isDark: isDark),
                  ],
                ),
                if (appointment.codigoReserva != null && appointment.codigoReserva!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkElevated : AppColors.background,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 12, color: AppColors.textTertiaryC(isDark)),
                        const SizedBox(width: 4),
                        Text(
                          appointment.codigoReserva!,
                          style: AppTypography.labelSmall,
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

  Widget _buildAvatar(_StatusConfig config, ResponsiveData responsive) {
    final size = responsive.isSmallPhone ? 44.0 : 50.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [config.color, config.color.withValues(alpha: 0.7)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        config.icon,
        color: AppColors.white,
        size: responsive.isSmallPhone ? 20 : 24,
      ),
    );
  }

  Widget _detailChip(IconData icon, String text, {required bool isDark, bool isHighlight = false}) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isHighlight ? AppColors.razer : AppColors.textTertiaryC(isDark)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: isHighlight ? AppColors.razer : null,
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
            color: AppColors.accent, icon: Icons.task_alt, isHighlighted: false);
      case 'Falta':
        return _StatusConfig(
            color: const Color(0xFF9333EA), icon: Icons.person_off, isHighlighted: true);
      case 'Pendiente':
        return const _StatusConfig(
            color: Color(0xFF2563EB), icon: Icons.schedule, isHighlighted: true);
      case 'Cancelado':
        return _StatusConfig(
            color: AppColors.textSecondary, icon: Icons.cancel_outlined, isHighlighted: false);
      default:
        return _StatusConfig(
            color: AppColors.textSecondary, icon: Icons.info, isHighlighted: false);
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
